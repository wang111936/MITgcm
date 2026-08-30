#!/usr/bin/env python3
"""Decode P5.3 production MDS output and evaluate P5-P01/P5-P02."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

import compare_p52_julia as common


END_TIME_S = 86_400
COMMON_PERIOD_S = 900
DT_VALUES = (900, 450, 225)
EXPECTED_IDS = (1001, 1002, 1003)
EXPECTED_TILES = ((1, 1), (1, 2), (2, 1), (2, 2))
EXPECTED_CODES = (2, 1, 1, 1, 1, 4)
TRAJ_FIELDS = 48
DIAG_OFFSET = 21
NDIAG = 27
COMP_ABS_TOL = 2.0e-12
COMP_REL_TOL = 5.0e-12
POS_ABS_TOL_M = 1.0e-6
POS_PATH_REL_TOL = 5.0e-11
CONVERGENCE_FLOOR_M = 1.0e-6
CONVERGENCE_INTERPRET_MULTIPLIER = 50.0
MIN_RK4_RATIO = 12.0
DIAG_NAMES = common.DIAG_NAMES
ORACLE_FIELDS = (
    "time_index", "particle_id", "time_s", "x_m", "y_m", "path_m",
    "rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES,
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_oracle(path: Path) -> dict[tuple[int, int], dict[str, float]]:
    rows = common.read_csv(path, ORACLE_FIELDS)
    require(len(rows) == 291, f"oracle row count differs: {path}")
    result: dict[tuple[int, int], dict[str, float]] = {}
    previous: tuple[int, int] | None = None
    for row in rows:
        key = (int(row["time_index"]), int(row["particle_id"]))
        require(previous is None or key > previous, f"oracle order differs: {path}")
        require(0 <= key[0] <= 96 and key[1] in EXPECTED_IDS, f"oracle key: {key}")
        values = {name: float(row[name]) for name in ORACLE_FIELDS[2:]}
        require(all(math.isfinite(value) for value in values.values()), f"oracle non-finite: {key}")
        require(values["time_s"] == key[0] * COMMON_PERIOD_S, f"oracle time: {key}")
        result[key] = values
        previous = key
    expected = {(index, particle_id) for index in range(97) for particle_id in EXPECTED_IDS}
    require(set(result) == expected, f"oracle key inventory differs: {path}")
    return result


def decode_trajectory(
    run_dir: Path, dt_s: int
) -> tuple[dict[tuple[int, int], dict[str, object]], dict[str, object]]:
    n_steps = END_TIME_S // dt_s
    stride = COMMON_PERIOD_S // dt_s
    expected_iterations = tuple(range(stride, n_steps + 1, stride))
    require(len(expected_iterations) == 96, f"common output count dt={dt_s}")
    pattern = re.compile(r"^bom_traj\.(\d{10})\.(\d{3})\.(\d{3})\.data$")
    indexed: dict[int, list[Path]] = defaultdict(list)
    for path in run_dir.iterdir():
        match = pattern.match(path.name)
        if match:
            indexed[int(match.group(1))].append(path)
    require(tuple(sorted(indexed)) == expected_iterations, f"trajectory suffix set dt={dt_s}")

    actual: dict[tuple[int, int], dict[str, object]] = {}
    expected_files: set[str] = set()
    tile_counts: dict[str, int] = {}
    for common_index, iteration in enumerate(expected_iterations, start=1):
        paths = sorted(indexed[iteration], key=common.tile_from_name)
        require(tuple(common.tile_from_name(path) for path in paths) == EXPECTED_TILES,
                f"tile set dt={dt_s} iter={iteration}")
        frame: list[tuple[int, tuple[float, ...], tuple[int, int]]] = []
        time_s = common_index * COMMON_PERIOD_S
        for path in paths:
            meta = path.with_suffix(".meta")
            require(meta.is_file(), f"missing metadata: {meta}")
            expected_files.update((path.name, meta.name))
            records = common.read_be64_records(path, TRAJ_FIELDS)
            common.check_meta(meta, TRAJ_FIELDS, len(records), iteration)
            header = records[0]
            require(all(math.isfinite(value) for value in header), f"non-finite header: {path}")
            local_count = common.exact_int(header[2], f"{path}: local count")
            require(len(records) == local_count + 1, f"record count: {path}")
            require(header[:2] == (2.0, 48.0), f"schema: {path}")
            require(common.exact_int(header[3], f"{path}: global count") == 3,
                    f"global count: {path}")
            require(header[4:7] == (1.0, 1.0, 64.0), f"version/precision: {path}")
            require(common.exact_int(header[7], f"{path}: iteration") == iteration,
                    f"iteration: {path}")
            require(header[8:11] == (float(time_s), float(time_s), float(time_s + 900)),
                    f"sample schedule: {path}")
            require(header[11:13] == (2.0, 2.0), f"process grid: {path}")
            tile = common.tile_from_name(path)
            derived_tile = (
                1 + (common.exact_int(header[13], f"{path}: iGlobal") - 1) // 4,
                1 + (common.exact_int(header[14], f"{path}: jGlobal") - 1) // 3,
            )
            require(derived_tile == tile, f"tile origin: {path}")
            require(header[16:18] == (1.0, 1.0), f"local tile: {path}")
            codes = tuple(common.exact_int(header[index], f"{path}: code")
                          for index in range(18, 24))
            require(codes == EXPECTED_CODES, f"PAPER2024 code tuple: {path}")
            require(header[24:27] == (27.0, 22.0, 48.0), f"descriptor: {path}")
            require(all(value == 0.0 for value in header[27:]), f"reserved header: {path}")
            previous_id = 0
            for record in records[1:]:
                require(all(math.isfinite(value) for value in record), f"non-finite particle: {path}")
                particle_id = common.particle_id(record, str(path))
                require(particle_id > previous_id and particle_id in EXPECTED_IDS,
                        f"ID order/set: {path}")
                require(record[2] == 1.0 and record[20] == 1.0, f"status: {path}")
                require(record[3] == time_s and common.exact_int(record[4], "record iteration") == iteration,
                        f"record time/iteration: {path}")
                diag = common.check_diag(record, DIAG_OFFSET, f"dt={dt_s} iter={iteration} ID={particle_id}")
                require(record[17:20] == (header[15], header[16], header[17]),
                        f"owner tuple: {path}")
                frame.append((particle_id, record, tile))
                previous_id = particle_id
            tile_counts[f"{iteration:010d}.{tile[0]:03d}.{tile[1]:03d}"] = local_count
        frame.sort(key=lambda item: item[0])
        require(tuple(item[0] for item in frame) == EXPECTED_IDS,
                f"global ID inventory dt={dt_s} iter={iteration}")
        for particle_id, record, tile in frame:
            actual[(common_index, particle_id)] = {
                "model_iteration": iteration, "time_s": record[3],
                "x_m": record[5], "y_m": record[6],
                "rhs_x_m_s": record[15], "rhs_y_m_s": record[16],
                "diag": record[DIAG_OFFSET:DIAG_OFFSET + NDIAG],
                "tile": f"{tile[0]:03d}.{tile[1]:03d}",
            }
    observed_files = {
        path.name for path in run_dir.iterdir()
        if path.name.startswith("bom_traj.") and path.suffix in (".data", ".meta")
    }
    require(observed_files == expected_files, f"raw trajectory inventory dt={dt_s}")
    return actual, {
        "dt_s": dt_s, "model_steps": n_steps, "output_frames": 96,
        "tiles_per_frame": 4, "data_files": 384, "meta_files": 384,
        "particle_records": len(actual), "tile_local_counts": tile_counts,
    }


def normalize(
    input_bundle: Path,
    production: dict[tuple[int, int], dict[str, object]],
) -> dict[tuple[int, int], dict[str, float]]:
    initial = common.read_initial(input_bundle)
    result: dict[tuple[int, int], dict[str, float]] = {
        (0, particle_id): dict(initial[particle_id], path_m=0.0)
        for particle_id in EXPECTED_IDS
    }
    for index in range(1, 97):
        for particle_id in EXPECTED_IDS:
            current = production[(index, particle_id)]
            previous = result[(index - 1, particle_id)]
            x_m = float(current["x_m"])
            y_m = float(current["y_m"])
            result[(index, particle_id)] = {
                "time_s": float(current["time_s"]), "x_m": x_m, "y_m": y_m,
                "path_m": previous["path_m"]
                + math.hypot(x_m - previous["x_m"], y_m - previous["y_m"]),
            }
    return result


def write_normalized(
    output: Path,
    label: str,
    normalized: dict[tuple[int, int], dict[str, float]],
) -> None:
    rows = [
        {"time_index": index, "particle_id": particle_id,
         **{name: f"{normalized[(index, particle_id)][name]:.17e}"
            for name in ("time_s", "x_m", "y_m", "path_m")}}
        for index in range(97) for particle_id in EXPECTED_IDS
    ]
    write_csv(output / f"normalized_{label}.csv", list(rows[0]), rows)


def write_case_plots(
    output: Path,
    prefix: str,
    title: str,
    normalized: dict[tuple[int, int], dict[str, float]],
    reference: dict[tuple[int, int], dict[str, float]],
) -> None:
    colors = ("#0072B2", "#56B4E9", "#D55E00", "#E69F00", "#009E73", "#66C2A5")
    for particle_id in EXPECTED_IDS:
        keys = [(index, particle_id) for index in range(97)]
        values = (
            [(normalized[key]["time_s"] / 3600.0, normalized[key]["x_m"]) for key in keys],
            [(reference[key]["time_s"] / 3600.0, reference[key]["x_m"]) for key in keys],
            [(normalized[key]["time_s"] / 3600.0, normalized[key]["y_m"]) for key in keys],
            [(reference[key]["time_s"] / 3600.0, reference[key]["y_m"]) for key in keys],
            [(normalized[key]["time_s"] / 3600.0, normalized[key]["path_m"]) for key in keys],
            [(reference[key]["time_s"] / 3600.0, reference[key]["path_m"]) for key in keys],
        )
        series = [
            (label, points, color)
            for label, points, color in zip(
                ("x actual", "x reference", "y actual", "y reference",
                 "path actual", "path reference"),
                values,
                colors,
            )
        ]
        common.svg_polyline(
            output / f"{prefix}_particle_{particle_id}_timeseries.svg",
            f"{title} particle {particle_id}: x, y and cumulative path",
            series,
            "time (hours)",
            "position/path (m)",
        )
    plan_series: list[tuple[str, list[tuple[float, float]], str]] = []
    for particle_id, color in zip(EXPECTED_IDS, ("#0072B2", "#D55E00", "#009E73")):
        plan_series.extend((
            (f"particle {particle_id} actual",
             [(normalized[(index, particle_id)]["x_m"], normalized[(index, particle_id)]["y_m"])
              for index in range(97)], color),
            (f"particle {particle_id} reference",
             [(reference[(index, particle_id)]["x_m"], reference[(index, particle_id)]["y_m"])
              for index in range(97)], color),
        ))
    common.svg_polyline(
        output / f"{prefix}_trajectory_planview.svg",
        f"{title} trajectory plan view",
        plan_series,
        "x (m)",
        "y (m)",
    )


def evaluate_p01(
    output: Path,
    production: dict[tuple[int, int], dict[str, object]],
    normalized: dict[tuple[int, int], dict[str, float]],
    oracle: dict[tuple[int, int], dict[str, float]],
    julia_components: Path,
    julia_trajectory: Path,
) -> dict[str, object]:
    trajectory_rows: list[dict[str, object]] = []
    normalized_component_rows: list[dict[str, object]] = []
    component_rows: list[dict[str, object]] = []
    max_position: dict[str, object] = {"error_m": -1.0}
    max_path: dict[str, object] = {"error_m": -1.0}
    max_component: dict[str, object] = {"error": -1.0}
    trajectory_failures = 0
    component_failures = 0

    for key in sorted(oracle):
        index, particle_id = key
        actual = normalized[key]
        reference = oracle[key]
        require(actual["time_s"] == reference["time_s"] == index * 900,
                f"P5-P01 time label: {key}")
        position_error = math.hypot(
            actual["x_m"] - reference["x_m"], actual["y_m"] - reference["y_m"]
        )
        path_error = abs(actual["path_m"] - reference["path_m"])
        tolerance = max(POS_ABS_TOL_M, POS_PATH_REL_TOL * abs(reference["path_m"]))
        passed = position_error <= tolerance and path_error <= tolerance
        trajectory_failures += int(not passed)
        if position_error > float(max_position["error_m"]):
            max_position = {"error_m": position_error, "time_index": index,
                            "particle_id": particle_id, "tolerance_m": tolerance}
        if path_error > float(max_path["error_m"]):
            max_path = {"error_m": path_error, "time_index": index,
                        "particle_id": particle_id, "tolerance_m": tolerance}
        trajectory_rows.append({
            "time_index": index, "particle_id": particle_id,
            "time_s": f"{actual['time_s']:.17e}",
            "actual_x_m": f"{actual['x_m']:.17e}",
            "reference_x_m": f"{reference['x_m']:.17e}",
            "actual_y_m": f"{actual['y_m']:.17e}",
            "reference_y_m": f"{reference['y_m']:.17e}",
            "position_error_m": f"{position_error:.17e}",
            "actual_path_m": f"{actual['path_m']:.17e}",
            "reference_path_m": f"{reference['path_m']:.17e}",
            "path_error_m": f"{path_error:.17e}",
            "tolerance_m": f"{tolerance:.17e}", "result": "PASS" if passed else "FAIL",
        })
    write_csv(output / "p01_trajectory_errors.csv", list(trajectory_rows[0]), trajectory_rows)

    compare_names = ("rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES)
    for index in range(1, 97):
        for particle_id in EXPECTED_IDS:
            key = (index, particle_id)
            record = production[key]
            actual_values = {
                "rhs_x_m_s": float(record["rhs_x_m_s"]),
                "rhs_y_m_s": float(record["rhs_y_m_s"]),
                **dict(zip(DIAG_NAMES, record["diag"])),
            }
            normalized_component_rows.append({
                "time_index": index,
                "particle_id": particle_id,
                "time_s": f"{float(record['time_s']):.17e}",
                **{component: f"{actual_values[component]:.17e}"
                   for component in compare_names},
            })
            for component in compare_names:
                actual = actual_values[component]
                reference = oracle[key][component]
                error = abs(actual - reference)
                tolerance = COMP_ABS_TOL + COMP_REL_TOL * abs(reference)
                passed = error <= tolerance
                component_failures += int(not passed)
                if error > float(max_component["error"]):
                    max_component = {
                        "error": error, "time_index": index, "particle_id": particle_id,
                        "component": component, "actual": actual,
                        "reference": reference, "tolerance": tolerance,
                    }
                component_rows.append({
                    "time_index": index, "particle_id": particle_id,
                    "time_s": f"{float(record['time_s']):.17e}",
                    "component": component, "actual": f"{actual:.17e}",
                    "reference": f"{reference:.17e}", "abs_error": f"{error:.17e}",
                    "tolerance": f"{tolerance:.17e}", "result": "PASS" if passed else "FAIL",
                })
    write_csv(output / "p01_component_errors.csv", list(component_rows[0]), component_rows)
    write_csv(
        output / "p01_normalized_components.csv",
        list(normalized_component_rows[0]),
        normalized_component_rows,
    )

    julia_component_rows = common.read_csv(
        julia_components,
        ("time_index", "particle_id", "time_s", "x_m", "y_m",
         "rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES),
    )
    julia_component = next(
        float(row["dv_e"]) for row in julia_component_rows
        if int(row["time_index"]) == 1 and int(row["particle_id"]) == 1001
    )
    paper_component = oracle[(1, 1001)]["dv_e"]
    component_difference = abs(paper_component - julia_component)
    component_bound = COMP_ABS_TOL + COMP_REL_TOL * abs(julia_component)

    julia_traj_rows = common.read_csv(
        julia_trajectory, ("particle_id", "time_s", "x_m", "y_m", "path_m")
    )
    julia_traj = next(
        row for row in julia_traj_rows
        if int(row["particle_id"]) == 1003 and float(row["time_s"]) == 86_400.0
    )
    julia_x = float(julia_traj["x_m"])
    julia_path = float(julia_traj["path_m"])
    paper_x = oracle[(96, 1003)]["x_m"]
    trajectory_difference = abs(paper_x - julia_x)
    trajectory_bound = max(POS_ABS_TOL_M, POS_PATH_REL_TOL * abs(julia_path))
    discrimination = {
        "component": {
            "name": "dv_e", "time_index": 1, "particle_id": 1001,
            "paper": paper_component, "julia": julia_component,
            "difference": component_difference, "roundoff_bound": component_bound,
            "required_multiplier": 10.0,
            "result": "PASS" if component_difference > 10.0 * component_bound else "FAIL",
        },
        "trajectory": {
            "name": "x_m", "time_index": 96, "particle_id": 1003,
            "paper": paper_x, "julia": julia_x,
            "difference": trajectory_difference, "roundoff_bound": trajectory_bound,
            "required_multiplier": 10.0,
            "result": "PASS" if trajectory_difference > 10.0 * trajectory_bound else "FAIL",
        },
    }
    result_status = (
        "PASS" if trajectory_failures == 0 and component_failures == 0
        and all(entry["result"] == "PASS" for entry in discrimination.values())
        else "FAIL"
    )
    result = {
        "schema": "MITGCM-BOM-P5-P01-result-v1", "result": result_status,
        "trajectory": {
            "rows": len(trajectory_rows), "failures": trajectory_failures,
            "max_position": max_position, "max_path": max_path,
            "tolerance": {"absolute_m": POS_ABS_TOL_M,
                          "relative_to_reference_path": POS_PATH_REL_TOL},
        },
        "components": {
            "production_rows": 288, "comparisons": len(component_rows),
            "failures": component_failures, "max": max_component,
            "tolerance": {"absolute": COMP_ABS_TOL, "relative": COMP_REL_TOL},
        },
        "mode_discrimination": discrimination,
    }
    (output / "p01_result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    return result


def evaluate_p02(
    output: Path,
    normalized_by_dt: dict[int, dict[tuple[int, int], dict[str, float]]],
    same_step_reference_by_dt: dict[int, dict[tuple[int, int], dict[str, float]]],
    fine_reference: dict[tuple[int, int], dict[str, float]],
) -> dict[str, object]:
    same_step_rows: list[dict[str, object]] = []
    same_step_failures = 0
    max_same_step: dict[str, object] = {"error_m": -1.0}
    for dt_s in DT_VALUES:
        for key in sorted(same_step_reference_by_dt[dt_s]):
            index, particle_id = key
            actual = normalized_by_dt[dt_s][key]
            reference = same_step_reference_by_dt[dt_s][key]
            error = math.hypot(
                actual["x_m"] - reference["x_m"], actual["y_m"] - reference["y_m"]
            )
            tolerance = max(POS_ABS_TOL_M, POS_PATH_REL_TOL * abs(reference["path_m"]))
            passed = error <= tolerance
            same_step_failures += int(not passed)
            if error > float(max_same_step["error_m"]):
                max_same_step = {
                    "error_m": error, "dt_s": dt_s, "time_index": index,
                    "particle_id": particle_id, "tolerance_m": tolerance,
                }
            same_step_rows.append({
                "dt_s": dt_s, "time_index": index, "particle_id": particle_id,
                "position_error_m": f"{error:.17e}",
                "tolerance_m": f"{tolerance:.17e}",
                "result": "PASS" if passed else "FAIL",
            })
    write_csv(output / "p02_same_step_errors.csv", list(same_step_rows[0]), same_step_rows)

    norms: dict[tuple[int, int, str], float] = {}
    norm_rows: list[dict[str, object]] = []
    for particle_id in EXPECTED_IDS:
        for dt_s in DT_VALUES:
            actual = normalized_by_dt[dt_s]
            endpoint = math.hypot(
                actual[(96, particle_id)]["x_m"] - fine_reference[(96, particle_id)]["x_m"],
                actual[(96, particle_id)]["y_m"] - fine_reference[(96, particle_id)]["y_m"],
            )
            full = max(
                math.hypot(
                    actual[(index, particle_id)]["x_m"] - fine_reference[(index, particle_id)]["x_m"],
                    actual[(index, particle_id)]["y_m"] - fine_reference[(index, particle_id)]["y_m"],
                )
                for index in range(97)
            )
            norms[(particle_id, dt_s, "endpoint")] = endpoint
            norms[(particle_id, dt_s, "full_linf")] = full
            norm_rows.extend((
                {"particle_id": particle_id, "dt_s": dt_s, "norm": "endpoint",
                 "error_m": f"{endpoint:.17e}"},
                {"particle_id": particle_id, "dt_s": dt_s, "norm": "full_linf",
                 "error_m": f"{full:.17e}"},
            ))
    write_csv(output / "p02_norms.csv", list(norm_rows[0]), norm_rows)

    ratio_rows: list[dict[str, object]] = []
    failures = same_step_failures
    for particle_id in EXPECTED_IDS:
        for norm_name in ("endpoint", "full_linf"):
            errors = [norms[(particle_id, dt_s, norm_name)] for dt_s in DT_VALUES]
            require(all(math.isfinite(error) for error in errors), "non-finite convergence norm")
            decreasing = errors[0] > errors[1] > errors[2]
            failures += int(not decreasing)
            for coarse_index, (coarse_dt, fine_dt) in enumerate(((900, 450), (450, 225))):
                coarse = errors[coarse_index]
                fine = errors[coarse_index + 1]
                ratio = math.inf if fine == 0.0 else coarse / fine
                interpreted = coarse > CONVERGENCE_INTERPRET_MULTIPLIER * CONVERGENCE_FLOOR_M
                passed = decreasing and (not interpreted or ratio >= MIN_RK4_RATIO)
                failures += int(interpreted and ratio < MIN_RK4_RATIO)
                ratio_rows.append({
                    "particle_id": particle_id, "norm": norm_name,
                    "coarse_dt_s": coarse_dt, "fine_dt_s": fine_dt,
                    "coarse_error_m": f"{coarse:.17e}",
                    "fine_error_m": f"{fine:.17e}",
                    "ratio": "inf" if math.isinf(ratio) else f"{ratio:.17e}",
                    "interpreted": "yes" if interpreted else "no",
                    "minimum_ratio": f"{MIN_RK4_RATIO:.1f}",
                    "result": "PASS" if passed else "FAIL",
                })
    write_csv(output / "p02_ratios.csv", list(ratio_rows[0]), ratio_rows)
    result = {
        "schema": "MITGCM-BOM-P5-P02-result-v1",
        "result": "PASS" if failures == 0 else "FAIL",
        "reference": {
            "arithmetic": "python-decimal", "decimal_digits": 90,
            "minimum_binary_precision_bits": 298,
            "fixed_rk4_step_s": 28.125,
        },
        "norms": {
            "endpoint": "Euclidean position error at 86400 s",
            "full_linf": "maximum Euclidean position error over 97 common times",
        },
        "production_steps_s": list(DT_VALUES),
        "floor_m": CONVERGENCE_FLOOR_M,
        "interpret_above_floor_multiplier": CONVERGENCE_INTERPRET_MULTIPLIER,
        "minimum_interpreted_ratio": MIN_RK4_RATIO,
        "same_step_oracle": {
            "comparisons": len(same_step_rows), "failures": same_step_failures,
            "max": max_same_step,
            "tolerance": {"absolute_m": POS_ABS_TOL_M,
                          "relative_to_reference_path": POS_PATH_REL_TOL},
        },
        "norm_rows": len(norm_rows), "ratio_rows": len(ratio_rows),
        "failures": failures,
        "errors_m": {
            str(particle_id): {
                str(dt_s): {
                    norm_name: norms[(particle_id, dt_s, norm_name)]
                    for norm_name in ("endpoint", "full_linf")
                }
                for dt_s in DT_VALUES
            }
            for particle_id in EXPECTED_IDS
        },
    }
    (output / "p02_result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    return result


def compare(args: argparse.Namespace) -> dict[str, object]:
    args.output.mkdir(parents=True, exist_ok=False)
    p01_oracle = read_oracle(args.oracle / "p01_paper2024_dt0900.csv")
    p02_oracle_by_dt = {
        900: read_oracle(args.oracle / "p02_paper2024_dt0900.csv"),
        450: read_oracle(args.oracle / "p02_paper2024_dt0450.csv"),
        225: read_oracle(args.oracle / "p02_paper2024_dt0225.csv"),
    }
    fine_reference = read_oracle(args.oracle / "p02_paper2024_dt0028p125.csv")
    p01_production, p01_inventory = decode_trajectory(args.run_p01, 900)
    p01_normalized = normalize(args.input_p01, p01_production)
    write_normalized(args.output, "p01", p01_normalized)
    run_by_dt = {
        900: args.run_p02_dt900, 450: args.run_p02_dt450, 225: args.run_p02_dt225
    }
    input_by_dt = {
        900: args.input_p02_dt900, 450: args.input_p02_dt450, 225: args.input_p02_dt225
    }
    production_by_dt: dict[int, dict[tuple[int, int], dict[str, object]]] = {}
    normalized_by_dt: dict[int, dict[tuple[int, int], dict[str, float]]] = {}
    inventory: dict[str, object] = {"p01": p01_inventory, "p02": {}}
    for dt_s in DT_VALUES:
        production, case_inventory = decode_trajectory(run_by_dt[dt_s], dt_s)
        normalized = normalize(input_by_dt[dt_s], production)
        production_by_dt[dt_s] = production
        normalized_by_dt[dt_s] = normalized
        inventory["p02"][str(dt_s)] = case_inventory
        write_normalized(args.output, f"p02_dt{dt_s:04d}", normalized)

    p01 = evaluate_p01(
        args.output, p01_production, p01_normalized, p01_oracle,
        args.julia_components, args.julia_trajectory,
    )
    p02 = evaluate_p02(
        args.output, normalized_by_dt, p02_oracle_by_dt, fine_reference
    )
    write_case_plots(args.output, "p01", "P5-P01", p01_normalized, p01_oracle)
    write_case_plots(
        args.output, "p02", "P5-P02 dt=900 vs fine reference",
        normalized_by_dt[900], fine_reference,
    )
    aggregate = {
        "schema": "MITGCM-BOM-P5.3-result-v1",
        "result": "PASS" if p01["result"] == p02["result"] == "PASS" else "FAIL",
        "p5_p01": p01, "p5_p02": p02, "inventory": inventory,
    }
    (args.output / "inventory_audit.json").write_text(
        json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    (args.output / "result.json").write_text(
        json.dumps(aggregate, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    review = f"""# P5.3 PAPER2024 scientific comparison review

- Aggregate result: **{aggregate['result']}**
- P5-P01 result: **{p01['result']}**
- P5-P01 trajectory rows/failures: {p01['trajectory']['rows']}/{p01['trajectory']['failures']}
- P5-P01 component comparisons/failures: {p01['components']['comparisons']}/{p01['components']['failures']}
- Maximum P5-P01 position error: {p01['trajectory']['max_position']['error_m']:.17e} m
- Maximum P5-P01 path error: {p01['trajectory']['max_path']['error_m']:.17e} m
- Maximum P5-P01 component error: {p01['components']['max']['error']:.17e}
- Predeclared component discriminator: {p01['mode_discrimination']['component']['result']}
- Predeclared trajectory discriminator: {p01['mode_discrimination']['trajectory']['result']}
- P5-P02 result: **{p02['result']}**
- P5-P02 same-step oracle comparisons/failures: {p02['same_step_oracle']['comparisons']}/{p02['same_step_oracle']['failures']}
- P5-P02 norm rows/ratio rows/failures: {p02['norm_rows']}/{p02['ratio_rows']}/{p02['failures']}

The decoder reads raw tiled MDS trajectory data and metadata independently of
the production Fortran reader. The independent PAPER2024 oracle evaluates the
analytical affine fields directly and supplies both same-step acceptance and a
90-decimal-digit, 28.125 s fixed-RK4 temporal-convergence reference.
"""
    (args.output / "review.md").write_text(review, encoding="ascii")
    return aggregate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-p01", type=Path, required=True)
    parser.add_argument("--input-p01", type=Path, required=True)
    parser.add_argument("--run-p02-dt900", type=Path, required=True)
    parser.add_argument("--run-p02-dt450", type=Path, required=True)
    parser.add_argument("--run-p02-dt225", type=Path, required=True)
    parser.add_argument("--input-p02-dt900", type=Path, required=True)
    parser.add_argument("--input-p02-dt450", type=Path, required=True)
    parser.add_argument("--input-p02-dt225", type=Path, required=True)
    parser.add_argument("--oracle", type=Path, required=True)
    parser.add_argument("--julia-components", type=Path, required=True)
    parser.add_argument("--julia-trajectory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = compare(args)
    except Exception as error:
        if args.output.exists():
            (args.output / "result.json").write_text(
                json.dumps({"schema": "MITGCM-BOM-P5.3-result-v1",
                            "result": "FAIL", "error": str(error)}, indent=2) + "\n",
                encoding="ascii",
            )
        print(f"P5.3 COMPARISON FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    if result["result"] != "PASS":
        print("P5.3 COMPARISON FAIL: numerical acceptance", file=sys.stderr)
        raise SystemExit(1)
    print("P5.3 PAPER2024 COMPARISON PASS p01_components=8352 p02_ratios=12")


if __name__ == "__main__":
    main()
