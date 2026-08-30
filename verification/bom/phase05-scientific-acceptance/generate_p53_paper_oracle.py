#!/usr/bin/env python3
"""Independent high-precision PAPER2024 component and RK4 trajectory oracle."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from decimal import Decimal, getcontext, localcontext
from pathlib import Path


SCHEMA = "MITGCM-BOM-P5-PAPER2024-ORACLE-v1"
DECIMAL_DIGITS = 90
getcontext().prec = DECIMAL_DIGITS
COMMON_STEP = Decimal("900")
END_TIME = Decimal("86400")
P02_STEP_LABELS = (
    ("0900", Decimal("900")),
    ("0450", Decimal("450")),
    ("0225", Decimal("225")),
    ("0028p125", Decimal("28.125")),
)
PARTICLES = (
    (1001, Decimal("80000"), Decimal("60000")),
    (1002, Decimal("200000"), Decimal("150000")),
    (1003, Decimal("320000"), Decimal("240000")),
)
ALPHA = Decimal("0.00337")
TAU = Decimal("0.0103") * Decimal("86400")
R_VALUE = Decimal("0.823")
SIGMA = Decimal("1.2")
F_CORI = Decimal("2.18213") / Decimal("86400")
TAU_SPHERE = Decimal("0")

# Frozen analytical input functions, transcribed independently from the
# accepted B16 input table.  Keys are (Eulerian/Stokes/Wind, east/north).
P01_FIELDS = {
    (1, 1): tuple(map(Decimal, (
        "1.2000000000000000e-1", "1.1000000000000000e-7",
        "-7.0000000000000000e-8", "2.0000000000000000e-7"))),
    (1, 2): tuple(map(Decimal, (
        "-5.0000000000000000e-2", "4.0000000000000000e-8",
        "9.0000000000000000e-8", "-1.2000000000000000e-7"))),
    (2, 1): tuple(map(Decimal, (
        "1.5000000000000000e-2", "-3.0000000000000000e-8",
        "2.0000000000000000e-8", "4.0000000000000000e-8"))),
    (2, 2): tuple(map(Decimal, (
        "8.0000000000000000e-3", "5.0000000000000000e-8",
        "-4.0000000000000000e-8", "3.0000000000000000e-8"))),
    (3, 1): tuple(map(Decimal, (
        "3.2000000000000002e+0", "1.4000000000000000e-6",
        "2.0000000000000000e-7", "-1.0000000000000000e-6"))),
    (3, 2): tuple(map(Decimal, (
        "-1.1000000000000001e+0", "-3.0000000000000004e-7",
        "1.1000000000000000e-6", "8.0000000000000002e-7"))),
}
DIAG_NAMES = (
    "vbase_e", "vbase_n", "vs_e", "vs_n", "vw_e", "vw_n",
    "v_e", "v_n", "u_e", "u_n", "dv_e", "dv_n", "du_e", "du_n",
    "omega", "f_cori", "tau_sphere", "c_v", "c_u",
    "rot_v_e", "rot_v_n", "rot_u_e", "rot_u_n",
    "inert_e", "inert_n", "drift_e", "drift_n",
)
CSV_FIELDS = (
    "time_index", "particle_id", "time_s", "x_m", "y_m", "path_m",
    "rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_fields(path: Path) -> dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]]:
    fields: dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]] = {}
    with path.open(newline="", encoding="ascii") as stream:
        for row in csv.DictReader(stream):
            key = (int(row["source_code"]), int(row["component_code"]))
            fields[key] = tuple(Decimal(row[name]) for name in (
                "c0_m_s", "cx_s_inv", "cy_s_inv", "ct_m_s2"
            ))
    expected = {(source, component) for source in range(1, 4) for component in range(1, 3)}
    if set(fields) != expected:
        raise ValueError("P5-P02 affine fixture has an unexpected key set")
    return fields


def affine(
    fields: dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]],
    key: tuple[int, int],
    x: Decimal,
    y: Decimal,
    t: Decimal,
) -> Decimal:
    c0, cx, cy, ct = fields[key]
    return c0 + cx * x + cy * y + ct * t


def covariant(
    east: Decimal,
    north: Decimal,
    dt_east: Decimal,
    dt_north: Decimal,
    de_east: Decimal,
    dn_east: Decimal,
    de_north: Decimal,
    dn_north: Decimal,
) -> tuple[Decimal, Decimal, Decimal]:
    material_e = (
        dt_east + east * de_east + north * dn_east
        - TAU_SPHERE * east * north
    )
    material_n = (
        dt_north + east * de_north + north * dn_north
        + TAU_SPHERE * east * east
    )
    vorticity = de_north - dn_east + TAU_SPHERE * east
    return material_e, material_n, vorticity


def rhs(
    fields: dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]],
    x: Decimal, y: Decimal, t: Decimal
) -> tuple[Decimal, Decimal, tuple[Decimal, ...]]:
    values = {(source, component): affine(fields, (source, component), x, y, t)
              for source in range(1, 4) for component in range(1, 3)}

    v_e = values[(1, 1)] + SIGMA * values[(2, 1)]
    v_n = values[(1, 2)] + SIGMA * values[(2, 2)]
    v_dt_e = fields[(1, 1)][3] + SIGMA * fields[(2, 1)][3]
    v_dt_n = fields[(1, 2)][3] + SIGMA * fields[(2, 2)][3]
    v_de_e = fields[(1, 1)][1] + SIGMA * fields[(2, 1)][1]
    v_dn_e = fields[(1, 1)][2] + SIGMA * fields[(2, 1)][2]
    v_de_n = fields[(1, 2)][1] + SIGMA * fields[(2, 2)][1]
    v_dn_n = fields[(1, 2)][2] + SIGMA * fields[(2, 2)][2]

    one_minus_alpha = Decimal(1) - ALPHA
    u_e = one_minus_alpha * v_e + ALPHA * values[(3, 1)]
    u_n = one_minus_alpha * v_n + ALPHA * values[(3, 2)]
    u_dt_e = one_minus_alpha * v_dt_e + ALPHA * fields[(3, 1)][3]
    u_dt_n = one_minus_alpha * v_dt_n + ALPHA * fields[(3, 2)][3]
    u_de_e = one_minus_alpha * v_de_e + ALPHA * fields[(3, 1)][1]
    u_dn_e = one_minus_alpha * v_dn_e + ALPHA * fields[(3, 1)][2]
    u_de_n = one_minus_alpha * v_de_n + ALPHA * fields[(3, 2)][1]
    u_dn_n = one_minus_alpha * v_dn_n + ALPHA * fields[(3, 2)][2]

    dv_e, dv_n, omega = covariant(
        v_e, v_n, v_dt_e, v_dt_n, v_de_e, v_dn_e, v_de_n, v_dn_n
    )
    du_e, du_n, _omega_u = covariant(
        u_e, u_n, u_dt_e, u_dt_n, u_de_e, u_dn_e, u_de_n, u_dn_n
    )

    omega_third = omega / Decimal(3)
    c_v = F_CORI + omega_third
    c_u = F_CORI + TAU_SPHERE * u_e + R_VALUE * omega_third
    rot_v_e = -R_VALUE * c_v * v_n
    rot_v_n = R_VALUE * c_v * v_e
    rot_u_e = c_u * u_n
    rot_u_n = -c_u * u_e
    inert_e = R_VALUE * dv_e + rot_v_e - du_e + rot_u_e
    inert_n = R_VALUE * dv_n + rot_v_n - du_n + rot_u_n
    drift_e = u_e + TAU * inert_e
    drift_n = u_n + TAU * inert_n

    diag = (
        values[(1, 1)], values[(1, 2)], values[(2, 1)], values[(2, 2)],
        values[(3, 1)], values[(3, 2)], v_e, v_n, u_e, u_n,
        dv_e, dv_n, du_e, du_n, omega, F_CORI, TAU_SPHERE, c_v, c_u,
        rot_v_e, rot_v_n, rot_u_e, rot_u_n, inert_e, inert_n,
        drift_e, drift_n,
    )
    if len(diag) != 27 or not all(value.is_finite() for value in diag):
        raise ArithmeticError("non-finite or incomplete PAPER2024 component vector")
    return drift_e, drift_n, diag


def rk4_step(
    fields: dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]],
    x: Decimal, y: Decimal, time: Decimal, step: Decimal
) -> tuple[Decimal, Decimal]:
    half = step / Decimal(2)
    sixth = step / Decimal(6)
    k1x, k1y, _ = rhs(fields, x, y, time)
    k2x, k2y, _ = rhs(fields, x + half * k1x, y + half * k1y, time + half)
    k3x, k3y, _ = rhs(fields, x + half * k2x, y + half * k2y, time + half)
    k4x, k4y, _ = rhs(fields, x + step * k3x, y + step * k3y, time + step)
    return (
        x + sixth * (k1x + Decimal(2) * k2x + Decimal(2) * k3x + k4x),
        y + sixth * (k1y + Decimal(2) * k2y + Decimal(2) * k3y + k4y),
    )


def decimal_text(value: Decimal) -> str:
    return format(value, ".80E")


def generate_csv(
    path: Path,
    step: Decimal,
    fields: dict[tuple[int, int], tuple[Decimal, Decimal, Decimal, Decimal]],
) -> int:
    ratio = COMMON_STEP / step
    if ratio != ratio.to_integral_value():
        raise ValueError(f"step does not divide common interval: {step}")
    output_stride = int(ratio)
    total_steps_decimal = END_TIME / step
    if total_steps_decimal != total_steps_decimal.to_integral_value():
        raise ValueError(f"step does not divide end time: {step}")
    total_steps = int(total_steps_decimal)
    states = {particle_id: (x, y) for particle_id, x, y in PARTICLES}
    paths = {particle_id: Decimal(0) for particle_id, _x, _y in PARTICLES}
    rows = 0
    with path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        for model_step in range(total_steps + 1):
            time = step * model_step
            if model_step % output_stride == 0:
                common_index = model_step // output_stride
                for particle_id, _x0, _y0 in PARTICLES:
                    x, y = states[particle_id]
                    rate_x, rate_y, diag = rhs(fields, x, y, time)
                    values = (
                        common_index, particle_id, decimal_text(time),
                        decimal_text(x), decimal_text(y),
                        decimal_text(paths[particle_id]),
                        decimal_text(rate_x), decimal_text(rate_y),
                        *(decimal_text(value) for value in diag),
                    )
                    writer.writerow(dict(zip(CSV_FIELDS, values)))
                    rows += 1
            if model_step == total_steps:
                break
            next_states: dict[int, tuple[Decimal, Decimal]] = {}
            for particle_id, _x0, _y0 in PARTICLES:
                x, y = states[particle_id]
                next_x, next_y = rk4_step(fields, x, y, time, step)
                paths[particle_id] += (
                    (next_x - x) * (next_x - x) + (next_y - y) * (next_y - y)
                ).sqrt()
                next_states[particle_id] = (next_x, next_y)
            states = next_states
    if rows != 291:
        raise AssertionError(f"oracle row count differs: {rows}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo-root", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    repo = args.repo_root.resolve()
    if output.exists():
        raise FileExistsError(f"P5.3 oracle refuses existing output: {output}")
    output.mkdir(parents=True)

    p02_field_path = (
        repo
        / "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv"
    )
    p02_fields = load_fields(p02_field_path)

    generated: list[Path] = []
    with localcontext() as context:
        context.prec = DECIMAL_DIGITS
        path = output / "p01_paper2024_dt0900.csv"
        generate_csv(path, Decimal("900"), P01_FIELDS)
        generated.append(path)
        for label, step in P02_STEP_LABELS:
            path = output / f"p02_paper2024_dt{label}.csv"
            generate_csv(path, step, p02_fields)
            generated.append(path)

    source = Path(__file__).resolve()
    contract = repo / "verification/bom/phase05-scientific-acceptance/P5.3_TEST_CONTRACT.md"
    manifest = {
        "schema": SCHEMA,
        "arithmetic": {
            "implementation": "python-decimal",
            "decimal_digits": DECIMAL_DIGITS,
            "minimum_binary_precision_bits": 298,
        },
        "time": {
            "end_s": "86400",
            "common_output_s": "900",
            "p01_step_s": "900",
            "p02_steps_s": {label: str(step) for label, step in P02_STEP_LABELS},
            "fine_reference_step_s": "28.125",
        },
        "equation": "PAPER2024 independent total-field covariant equation",
        "cases": {
            "p01": "Case J fields and parameters",
            "p02": "dedicated smooth affine convergence fields; Case J grid, particles and parameters",
        },
        "parameters": {
            "alpha": str(ALPHA), "tau_s": str(TAU), "r": str(R_VALUE),
            "sigma": str(SIGMA), "f_cori_s_inv": str(F_CORI),
            "tau_sphere_m_inv": str(TAU_SPHERE),
        },
        "particles": [
            {"id": particle_id, "x_m": str(x), "y_m": str(y)}
            for particle_id, x, y in PARTICLES
        ],
        "source_sha256": sha256(source),
        "contract_sha256": sha256(contract),
        "p02_affine_fixture_sha256": sha256(p02_field_path),
        "files": {
            path.name: {"rows": 291, "bytes": path.stat().st_size,
                        "sha256": sha256(path)}
            for path in generated
        },
    }
    manifest_path = output / "oracle-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    generated.append(manifest_path)
    checksum_path = output / "SHA256SUMS"
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.name}\n" for path in sorted(generated)),
        encoding="ascii",
    )
    print("P5.3 PAPER2024 ORACLE PASS files=5 rows=1455 precision_digits=90")


if __name__ == "__main__":
    main()
