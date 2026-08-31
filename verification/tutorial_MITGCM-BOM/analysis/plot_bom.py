#!/usr/bin/env python3
"""Decode tiled MITGCM-BOM schema-2 trajectories and plot plan-view tracks."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import struct
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


FILE_PATTERN = re.compile(
    r"^bom_traj\.(?P<suffix>[0-9]{10})\.(?P<bi>[0-9]{3})\.(?P<bj>[0-9]{3})\.data$"
)
SCHEMA = 2
WIDTH = 48
ID_RADIX = 2**32


@dataclass(frozen=True)
class ParticleRecord:
    suffix: str
    iteration: int
    time_s: float
    particle_id: int
    status: int
    x: float
    y: float
    release_time_s: float
    age_s: float
    base_u: float
    base_v: float
    wind_u: float
    wind_v: float
    drift_u: float
    drift_v: float
    rank: int
    tile_bi: int
    tile_bj: int


def exact_int(value: float, label: str) -> int:
    if not math.isfinite(value) or value != round(value):
        raise ValueError(f"{label} is not an exact integer: {value!r}")
    return int(value)


def read_records(path: Path) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    record_bytes = WIDTH * 8
    if len(payload) == 0 or len(payload) % record_bytes != 0:
        raise ValueError(
            f"{path.name}: byte size {len(payload)} is not a positive multiple of {record_bytes}"
        )
    values = struct.unpack(f">{len(payload) // 8}d", payload)
    if not all(math.isfinite(value) for value in values):
        raise ValueError(f"{path.name}: non-finite binary64 value")
    return [
        tuple(values[offset : offset + WIDTH])
        for offset in range(0, len(values), WIDTH)
    ]


def discover(run_dir: Path) -> dict[str, list[Path]]:
    grouped: dict[str, list[Path]] = defaultdict(list)
    for path in sorted(run_dir.iterdir(), key=lambda item: item.name):
        match = FILE_PATTERN.match(path.name)
        if match:
            grouped[match.group("suffix")].append(path)
    if not grouped:
        raise FileNotFoundError(f"no schema-2 BOM trajectory members in {run_dir}")
    return dict(sorted(grouped.items()))


def decode_frame(suffix: str, paths: Iterable[Path]) -> tuple[list[ParticleRecord], dict[str, int | float]]:
    owners: list[ParticleRecord] = []
    expected_global: int | None = None
    header_iteration: int | None = None
    sample_time: float | None = None
    equation_code: int | None = None
    source_files = 0

    for path in sorted(paths, key=lambda item: item.name):
        source_files += 1
        records = read_records(path)
        header = records[0]
        schema = exact_int(header[0], f"{path.name} schema")
        width = exact_int(header[1], f"{path.name} width")
        local_count = exact_int(header[2], f"{path.name} local count")
        frame_expected = exact_int(header[3], f"{path.name} global count")
        iteration = exact_int(header[7], f"{path.name} iteration")
        frame_time = header[8]
        frame_equation = exact_int(header[19], f"{path.name} equation code")

        if schema != SCHEMA or width != WIDTH:
            raise ValueError(f"{path.name}: expected schema/width {SCHEMA}/{WIDTH}, got {schema}/{width}")
        if local_count < 0 or len(records) != local_count + 1:
            raise ValueError(
                f"{path.name}: header count {local_count} but physical records {len(records) - 1}"
            )
        if expected_global is None:
            expected_global = frame_expected
            header_iteration = iteration
            sample_time = frame_time
            equation_code = frame_equation
        elif (
            frame_expected != expected_global
            or iteration != header_iteration
            or frame_time != sample_time
            or frame_equation != equation_code
        ):
            raise ValueError(f"{path.name}: tile header disagrees with frame {suffix}")

        for number, record in enumerate(records[1:], start=2):
            id_hi = exact_int(record[0], f"{path.name} record {number} ID high")
            id_lo = exact_int(record[1], f"{path.name} record {number} ID low")
            if not (0 <= id_hi < 2**31 and 0 <= id_lo < ID_RADIX):
                raise ValueError(f"{path.name} record {number}: ID word outside range")
            particle_id = id_hi * ID_RADIX + id_lo
            if particle_id <= 0:
                raise ValueError(f"{path.name} record {number}: nonpositive particle ID")
            record_time = record[3]
            record_iteration = exact_int(record[4], f"{path.name} record {number} iteration")
            if record_time != sample_time or record_iteration != header_iteration:
                raise ValueError(f"{path.name} record {number}: particle/header time mismatch")
            if exact_int(record[20], f"{path.name} record {number} marker") != 1:
                raise ValueError(f"{path.name} record {number}: inactive record marker")

            owners.append(
                ParticleRecord(
                    suffix=suffix,
                    iteration=record_iteration,
                    time_s=record_time,
                    particle_id=particle_id,
                    status=exact_int(record[2], f"{path.name} record {number} status"),
                    x=record[5],
                    y=record[6],
                    release_time_s=record[7],
                    age_s=record[8],
                    base_u=record[11],
                    base_v=record[12],
                    wind_u=record[13],
                    wind_v=record[14],
                    drift_u=record[15],
                    drift_v=record[16],
                    rank=exact_int(record[17], f"{path.name} record {number} rank"),
                    tile_bi=exact_int(record[18], f"{path.name} record {number} tile bi"),
                    tile_bj=exact_int(record[19], f"{path.name} record {number} tile bj"),
                )
            )

    if expected_global is None or header_iteration is None or sample_time is None or equation_code is None:
        raise ValueError(f"frame {suffix}: no tile header")
    if len(owners) != expected_global:
        raise ValueError(f"frame {suffix}: decoded {len(owners)} owners, expected {expected_global}")
    ids = [record.particle_id for record in owners]
    if len(ids) != len(set(ids)):
        raise ValueError(f"frame {suffix}: duplicate particle ID")
    owners.sort(key=lambda record: record.particle_id)
    return owners, {
        "iteration": header_iteration,
        "time_s": sample_time,
        "expected_particles": expected_global,
        "equation_code": equation_code,
        "tile_files": source_files,
    }


def path_length(records: list[ParticleRecord]) -> float:
    return sum(
        math.hypot(second.x - first.x, second.y - first.y)
        for first, second in zip(records, records[1:])
    )


def write_csv(path: Path, records: list[ParticleRecord]) -> None:
    fieldnames = [
        "suffix",
        "iteration",
        "time_s",
        "particle_id",
        "status",
        "x",
        "y",
        "release_time_s",
        "age_s",
        "base_u",
        "base_v",
        "wind_u",
        "wind_v",
        "drift_u",
        "drift_v",
        "rank",
        "tile_bi",
        "tile_bj",
    ]
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for record in records:
            writer.writerow({name: getattr(record, name) for name in fieldnames})


def write_plot(path: Path, by_particle: dict[int, list[ParticleRecord]]) -> None:
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise RuntimeError("Matplotlib is required to create bom_trajectory.png") from error

    figure, (axis, displacement_axis) = plt.subplots(
        1, 2, figsize=(13.0, 5.8), constrained_layout=True
    )
    for particle_id, records in sorted(by_particle.items()):
        x_km = [record.x / 1000.0 for record in records]
        y_km = [record.y / 1000.0 for record in records]
        dx_km = [(record.x - records[0].x) / 1000.0 for record in records]
        dy_km = [(record.y - records[0].y) / 1000.0 for record in records]
        line = axis.plot(x_km, y_km, linewidth=2.2, label=f"ID {particle_id}")[0]
        axis.scatter(x_km[0], y_km[0], s=42, marker="o", color=line.get_color(), zorder=3)
        axis.scatter(x_km[-1], y_km[-1], s=54, marker="x", color=line.get_color(), zorder=3)
        displacement_axis.plot(
            dx_km, dy_km, linewidth=2.2, color=line.get_color(), label=f"ID {particle_id}"
        )
        displacement_axis.scatter(
            dx_km[0], dy_km[0], s=42, marker="o", color=line.get_color(), zorder=3
        )
        displacement_axis.scatter(
            dx_km[-1], dy_km[-1], s=54, marker="x", color=line.get_color(), zorder=3
        )
    axis.set(
        title="Full-domain position",
        xlabel="x (km)",
        ylabel="y (km)",
        xlim=(0.0, 400.0),
        ylim=(0.0, 300.0),
    )
    axis.set_aspect("equal", adjustable="box")
    axis.grid(True, color="#c7d2de", linewidth=0.7, alpha=0.75)
    axis.legend(title="start: circle; end: cross", loc="best")
    displacement_axis.set(
        title="Displacement from first output",
        xlabel="delta x (km)",
        ylabel="delta y (km)",
    )
    displacement_axis.set_aspect("equal", adjustable="datalim")
    displacement_axis.grid(True, color="#c7d2de", linewidth=0.7, alpha=0.75)
    displacement_axis.axhline(0.0, color="#7f8c99", linewidth=0.7)
    displacement_axis.axvline(0.0, color="#7f8c99", linewidth=0.7)
    figure.suptitle("MITGCM-BOM controlled surface trajectories", fontsize=16)
    figure.savefig(path, dpi=180)
    plt.close(figure)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--expected-frames", type=int)
    parser.add_argument("--expected-particles", type=int)
    parser.add_argument("--expected-final-time", type=float)
    args = parser.parse_args()

    run_dir = args.run_dir.resolve()
    output_dir = args.output_dir.resolve()
    if not run_dir.is_dir():
        raise NotADirectoryError(run_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    grouped = discover(run_dir)
    all_records: list[ParticleRecord] = []
    frames: list[dict[str, int | float | str]] = []
    for suffix, paths in grouped.items():
        records, header = decode_frame(suffix, paths)
        all_records.extend(records)
        frames.append({"suffix": suffix, **header})

    frames.sort(key=lambda frame: (float(frame["time_s"]), int(frame["iteration"])))
    if any(
        float(second["time_s"]) <= float(first["time_s"])
        for first, second in zip(frames, frames[1:])
    ):
        raise ValueError("trajectory frame times are not strictly increasing")

    by_particle: dict[int, list[ParticleRecord]] = defaultdict(list)
    for record in sorted(all_records, key=lambda item: (item.particle_id, item.time_s)):
        by_particle[record.particle_id].append(record)
    if any(len(records) != len(frames) for records in by_particle.values()):
        raise ValueError("at least one particle is missing from a trajectory frame")

    if args.expected_frames is not None and len(frames) != args.expected_frames:
        raise ValueError(f"frame count {len(frames)} != expected {args.expected_frames}")
    if args.expected_particles is not None and len(by_particle) != args.expected_particles:
        raise ValueError(f"particle count {len(by_particle)} != expected {args.expected_particles}")
    final_time = float(frames[-1]["time_s"])
    if args.expected_final_time is not None and final_time != args.expected_final_time:
        raise ValueError(f"final time {final_time} != expected {args.expected_final_time}")

    csv_path = output_dir / "bom_trajectory.csv"
    json_path = output_dir / "bom_trajectory_summary.json"
    png_path = output_dir / "bom_trajectory.png"
    write_csv(csv_path, sorted(all_records, key=lambda item: (item.time_s, item.particle_id)))

    summary = {
        "schema": "MITGCM-BOM-TRAJECTORY-SUMMARY-v1",
        "trajectory_schema": SCHEMA,
        "record_width": WIDTH,
        "frame_count": len(frames),
        "particle_count": len(by_particle),
        "record_count": len(all_records),
        "first_time_s": float(frames[0]["time_s"]),
        "final_time_s": final_time,
        "equation_code": int(frames[0]["equation_code"]),
        "tile_file_count": sum(int(frame["tile_files"]) for frame in frames),
        "particles": {
            str(particle_id): {
                "first_x": records[0].x,
                "first_y": records[0].y,
                "final_x": records[-1].x,
                "final_y": records[-1].y,
                "path_length": path_length(records),
                "final_status": records[-1].status,
            }
            for particle_id, records in sorted(by_particle.items())
        },
    }
    json_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="ascii")
    write_plot(png_path, dict(by_particle))

    print(
        "MITGCM-BOM TRAJECTORY PASS "
        f"frames={len(frames)} particles={len(by_particle)} "
        f"records={len(all_records)} final_time_s={final_time:g}"
    )
    print(f"CSV: {csv_path}")
    print(f"JSON: {json_path}")
    print(f"PNG: {png_path}")


if __name__ == "__main__":
    main()
