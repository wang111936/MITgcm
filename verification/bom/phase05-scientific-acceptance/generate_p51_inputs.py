#!/usr/bin/env python3
"""Generate the deterministic production-input bundle frozen by P5-I01."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import struct
from pathlib import Path
from typing import Iterable


SCHEMA = "MITGCM-BOM-P5-I01-v1"
NX, NY, NR = 8, 6, 2
DX_M, DY_M = 50_000.0, 50_000.0
DEL_R_M = (50.0, 50.0)
DT_S = 900
N_STEPS = 96
TIMES_S = tuple(range(0, DT_S * N_STEPS + 1, DT_S))
F0_S_INV = 2.18213 / 86_400.0
PARTICLE_FIELDS = 8
BOM_ALIVE = 1

TEMPERATURE_COEFFICIENTS = {
    "c0": 20.0,
    "cx": 2.0e-6,
    "cy": -1.0e-6,
    "ct": 1.0e-7,
    "cz_per_level": -0.5,
}
NUTRIENT_COEFFICIENTS = {
    "c0": 1.5,
    "cx": 1.0e-6,
    "cy": -5.0e-7,
    "ct": 2.0e-7,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="ascii", newline="\n")


def pack_be64(values: Iterable[float]) -> bytes:
    sequence = tuple(values)
    return struct.pack(f">{len(sequence)}d", *sequence)


def write_be64(path: Path, values: Iterable[float]) -> None:
    path.write_bytes(pack_be64(values))


def load_affine_fields(path: Path) -> dict[tuple[int, int], dict[str, float]]:
    fields: dict[tuple[int, int], dict[str, float]] = {}
    with path.open(newline="", encoding="ascii") as stream:
        for row in csv.DictReader(stream):
            key = (int(row["source_code"]), int(row["component_code"]))
            fields[key] = {
                "c0": float(row["c0_m_s"]),
                "cx": float(row["cx_s_inv"]),
                "cy": float(row["cy_s_inv"]),
                "ct": float(row["ct_m_s2"]),
            }
    if set(fields) != {(source, component) for source in range(1, 4) for component in range(1, 3)}:
        raise ValueError("B16 affine field table has an unexpected key set")
    return fields


def load_particles(path: Path) -> list[tuple[int, float, float]]:
    particles: list[tuple[int, float, float]] = []
    with path.open(newline="", encoding="ascii") as stream:
        for row in csv.DictReader(stream):
            particles.append(
                (int(row["particle_id"]), float(row["x_m"]), float(row["y_m"]))
            )
    if len(particles) != 3:
        raise ValueError("P5-I01 expects exactly three locked B16 particles")
    return particles


def affine(coeff: dict[str, float], x: float, y: float, time_s: float) -> float:
    return coeff["c0"] + coeff["cx"] * x + coeff["cy"] * y + coeff["ct"] * time_s


def field_3d(
    coeff: dict[str, float], component: str, time_s: float
) -> list[float]:
    values: list[float] = []
    for _k in range(NR):
        for j in range(NY):
            for i in range(NX):
                if component == "u":
                    x = i * DX_M
                    y = (j + 0.5) * DY_M
                elif component == "v":
                    x = (i + 0.5) * DX_M
                    y = j * DY_M
                else:
                    raise ValueError(f"unknown C-grid component: {component}")
                values.append(affine(coeff, x, y, time_s))
    return values


def scalar_2d(coeff: dict[str, float], time_s: float) -> list[float]:
    return [
        affine(coeff, (i + 0.5) * DX_M, (j + 0.5) * DY_M, time_s)
        for j in range(NY)
        for i in range(NX)
    ]


def temperature_3d(time_s: float) -> list[float]:
    coeff = TEMPERATURE_COEFFICIENTS
    values: list[float] = []
    for k in range(NR):
        for j in range(NY):
            for i in range(NX):
                x = (i + 0.5) * DX_M
                y = (j + 0.5) * DY_M
                values.append(
                    coeff["c0"]
                    + coeff["cx"] * x
                    + coeff["cy"] * y
                    + coeff["ct"] * time_s
                    + coeff["cz_per_level"] * k
                )
    return values


def nutrient_2d(time_s: float) -> list[float]:
    return scalar_2d(NUTRIENT_COEFFICIENTS, time_s)


def split_id(particle_id: int) -> tuple[float, float]:
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def write_particle_mds(
    output: Path, particles: list[tuple[int, float, float]]
) -> None:
    header = (
        1.0,
        float(PARTICLE_FIELDS),
        float(len(particles)),
        1.0,
        1.0,
        64.0,
        0.0,
        0.0,
    )
    records = [header]
    for particle_id, x, y in particles:
        id_hi, id_lo = split_id(particle_id)
        records.append((id_hi, id_lo, x, y, 0.0, float(BOM_ALIVE), 0.0, 0.0))
    write_be64(output / "bom_particles.data", (value for record in records for value in record))
    write_text(
        output / "bom_particles.meta",
        """ nDims = [   3 ];
 dimList = [
     1,    1,    1,
     1,    1,    1,
     8,    1,    8
 ];
 dataprec = [ 'float64' ];
 nrecords = [     4 ];
 timeStepNumber = [          0 ];
 nFlds = [    1 ];
 fldList = {
 'BOMV0001'
 };
""",
    )


def data_text(end_time: int, pickup_frequency: int, run_name: str) -> str:
    del_x = ",".join(["50000."] * NX)
    del_y = ",".join(["50000."] * NY)
    return f"""# P5 scientific-acceptance controlled Cartesian experiment
 &PARM01
 tRef=10.,9.,
 sRef=35.,35.,
 viscAh=0.,
 viscAr=1.E-3,
 diffKhT=0.,
 diffKrT=0.,
 diffKhS=0.,
 diffKrS=0.,
 tAlpha=2.E-4,
 sBeta=7.4E-4,
 eosType='LINEAR',
 implicitFreeSurface=.TRUE.,
 momStepping=.FALSE.,
 tempStepping=.FALSE.,
 saltStepping=.FALSE.,
 readBinaryPrec=64,
 f0={F0_S_INV:.17e},
 beta=0.,
 &
 &PARM02
 cg2dMaxIters=50,
 cg2dTargetResidual=1.E-12,
 &
 &PARM03
 nIter0=0,
 startTime=0.,
 endTime={end_time}.,
 deltaTmom=900.,
 deltaTtracer=900.,
 deltaTClock=900.,
 pChkptFreq={pickup_frequency}.,
 chkptFreq=0.,
 dumpFreq=0.,
 monitorFreq=900.,
 &
 &PARM04
 usingCartesianGrid=.TRUE.,
 xgOrigin=0.,
 ygOrigin=0.,
 delX={del_x},
 delY={del_y},
 delR=50.,50.,
 &
 &PARM05
 bathyFile='bathy.bin',
 uVelInitFile='uvel_init.bin',
 vVelInitFile='vvel_init.bin',
 the_run_name='{run_name}',
 &
"""


def data_bom_text(equation_mode: str, biology: bool = False) -> str:
    p4 = """ bomUseBiology=.TRUE.,
 bomUseLand=.TRUE.,
 bomTempSource='THETA',
 bomNSource='FILES',
 bomBiologyMissingPolicy='STOP',
 bomMuMaxDay=0.20,
 bomMortDay=0.01,
 bomKN=2.,
 bomTMin=10.,
 bomTMax=40.,
 bomS0=1.,
 bomSMin=0.25,
 bomSMax=2.,
 bomBirthMaxTry=8,
 bomNFile='nutrient.bin',
 bomNStartTime=0.,
 bomNPeriod=900.,
 bomNRepCycle=0.,
 bomNInScale=1.,
 bomNFilePrec=64,
 bomEventFile='p5_events',
""" if biology else """ bomUseBiology=.FALSE.,
 bomUseLand=.FALSE.,
 bomTempSource='NONE',
 bomNSource='NONE',
"""
    return f""" &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='{equation_mode}',
 bomIntegrator='RK4',
 bomDeltaTTarget=900.,
 bomOutputFreq=900.,
 bomPickupFreq=43200.,
 bomSeed=20260830,
 bomMaxParticles=3,
 bomInitialIter=0,
 bomInitialFile='bom_particles',
 bomSpringLaw='NONE',
 bomNeighborPolicy='NONE',
 &
 &BOM_PARM02
 bomCurrentPolicy='EULERIAN',
 bomAlpha=0.00337,
 bomTauDays=0.0103,
 bomR=0.823,
 bomSigma=1.2,
 bomLeewayWindCoeff=0.,
 bomWindSource='EXF',
 bomStokesSource='FILES',
 bomUStokesFile='ustokes.bin',
 bomVStokesFile='vstokes.bin',
 bomStokesStartTime=0.,
 bomStokesPeriod=900.,
 bomStokesRepCycle=0.,
 bomStokesInScale=1.,
 bomStokesFilePrec=64,
 bomWetWeightMin=0.999999,
 bomAdvCFL=0.5,
 bomMaxHop=8,
 bomInitGlobalLimit=1000,
 bomCheckEverySubstep=.TRUE.,
 &
 &BOM_PARM03
{p4} &
"""


def write_configuration(output: Path) -> None:
    write_text(output / "data", data_text(86_400, 43_200, "P5-J01"))
    write_text(output / "data.smoke", data_text(1_800, 1_800, "P5-B01-SMOKE"))
    write_text(
        output / "data.pkg",
        """ &PACKAGES
 useOffLine=.TRUE.,
 useEXF=.TRUE.,
 useDiagnostics=.FALSE.,
 useMNC=.FALSE.,
 useBOM=.TRUE.,
 &
""",
    )
    write_text(
        output / "data.pkg.bomoff",
        """ &PACKAGES
 useOffLine=.FALSE.,
 useEXF=.FALSE.,
 useDiagnostics=.FALSE.,
 useMNC=.FALSE.,
 useBOM=.FALSE.,
 &
""",
    )
    write_text(
        output / "data.off",
        """ &OFFLINE_PARM01
 UvelFile='offline_u',
 VvelFile='offline_v',
 ThetFile='offline_theta',
 &
 &OFFLINE_PARM02
 offlineIter0=0,
 deltaToffline=900.,
 offlineTimeOffset=0.,
 offlineForcingPeriod=900.,
 offlineForcingCycle=0.,
 offlineLoadPrec=64,
 &
""",
    )
    write_text(
        output / "data.exf",
        """ &EXF_NML_01
 useExfCheckRange=.FALSE.,
 useExfYearlyFields=.FALSE.,
 useAtmWind=.TRUE.,
 useRelativeWind=.FALSE.,
 rotateStressOnAgrid=.FALSE.,
 exf_iprec=64,
 &
 &EXF_NML_02
 uwindfile='uwind.bin',
 vwindfile='vwind.bin',
 uwindStartTime=0.,
 vwindStartTime=0.,
 uwindperiod=900.,
 vwindperiod=900.,
 uwindRepCycle=0.,
 vwindRepCycle=0.,
 &
 &EXF_NML_03
 exf_inscal_uwind=1.,
 exf_inscal_vwind=1.,
 uwindconst=0.,
 vwindconst=0.,
 &
 &EXF_NML_04
 &
""",
    )
    write_text(output / "data.bom", data_bom_text("JULIA"))
    write_text(output / "data.bom.paper2024", data_bom_text("PAPER2024"))
    write_text(output / "data.bom.phase4", data_bom_text("PAPER2024", biology=True))
    write_text(
        output / "eedata",
        """ &EEPARMS
 nTx=1,
 nTy=1,
 &
""",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo-root", type=Path)
    args = parser.parse_args()
    repo_root = (
        args.repo_root.resolve()
        if args.repo_root is not None
        else Path(__file__).resolve().parents[3]
    )
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"P5-I01 refuses existing output: {output}")
    output.mkdir(parents=True)

    reference_root = repo_root / "verification/bom/reference/phase02"
    field_csv = reference_root / "input_fields_v1.csv"
    particle_csv = reference_root / "input_particles_v1.csv"
    parameter_toml = reference_root / "input_parameters_v1.toml"
    fields = load_affine_fields(field_csv)
    particles = load_particles(particle_csv)

    write_configuration(output)
    write_be64(output / "bathy.bin", [-100.0] * (NX * NY))
    write_be64(output / "uvel_init.bin", field_3d(fields[(1, 1)], "u", 0.0))
    write_be64(output / "vvel_init.bin", field_3d(fields[(1, 2)], "v", 0.0))
    write_particle_mds(output, particles)

    ustokes: list[float] = []
    vstokes: list[float] = []
    uwind: list[float] = []
    vwind: list[float] = []
    nutrient: list[float] = []
    for record, time_s in enumerate(TIMES_S):
        suffix = f"{record:010d}"
        write_be64(output / f"offline_u.{suffix}", field_3d(fields[(1, 1)], "u", time_s))
        write_be64(output / f"offline_v.{suffix}", field_3d(fields[(1, 2)], "v", time_s))
        write_be64(output / f"offline_theta.{suffix}", temperature_3d(time_s))
        ustokes.extend(scalar_2d(fields[(2, 1)], time_s))
        vstokes.extend(scalar_2d(fields[(2, 2)], time_s))
        uwind.extend(scalar_2d(fields[(3, 1)], time_s))
        vwind.extend(scalar_2d(fields[(3, 2)], time_s))
        nutrient.extend(nutrient_2d(time_s))
    write_be64(output / "ustokes.bin", ustokes)
    write_be64(output / "vstokes.bin", vstokes)
    write_be64(output / "uwind.bin", uwind)
    write_be64(output / "vwind.bin", vwind)
    write_be64(output / "nutrient.bin", nutrient)

    locks = {
        path.name: sha256(path) for path in (field_csv, particle_csv, parameter_toml)
    }
    generated = sorted(
        path for path in output.iterdir() if path.name not in {"input-manifest.json", "SHA256SUMS"}
    )
    manifest = {
        "schema": SCHEMA,
        "dimensions": {"nx": NX, "ny": NY, "nr": NR},
        "grid": {
            "coordinate_system": "cartesian_m",
            "x_origin_m": 0.0,
            "y_origin_m": 0.0,
            "dx_m": DX_M,
            "dy_m": DY_M,
            "del_r_m": list(DEL_R_M),
            "bathy_m": -100.0,
            "periodic_x": False,
            "periodic_y": False,
        },
        "time": {
            "start_s": 0,
            "end_s": TIMES_S[-1],
            "period_s": DT_S,
            "records": len(TIMES_S),
            "timestamps_s": list(TIMES_S),
        },
        "precision": {"binary": "IEEE754-binary64", "endianness": "big"},
        "c_grid": {
            "u": "x-face/y-center/i-fastest/k-outer",
            "v": "x-center/y-face/i-fastest/k-outer",
            "scalar": "x-center/y-center/i-fastest/record-outer",
        },
        "affine_fields": {
            f"source{source}_component{component}": coeff
            for (source, component), coeff in sorted(fields.items())
        },
        "temperature": TEMPERATURE_COEFFICIENTS,
        "nutrient": NUTRIENT_COEFFICIENTS,
        "particles": [
            {"id": particle_id, "x_m": x, "y_m": y, "status": BOM_ALIVE}
            for particle_id, x, y in particles
        ],
        "reference_locks": locks,
        "files": {
            path.name: {"bytes": path.stat().st_size, "sha256": sha256(path)}
            for path in generated
        },
    }
    manifest_path = output / "input-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="ascii"
    )
    checksum_paths = sorted([*generated, manifest_path], key=lambda path: path.name)
    write_text(
        output / "SHA256SUMS",
        "".join(f"{sha256(path)}  {path.name}\n" for path in checksum_paths),
    )
    print(
        f"P5-I01 INPUT GENERATION PASS files={len(checksum_paths) + 1} "
        f"records={len(TIMES_S)} output={output}"
    )


if __name__ == "__main__":
    main()
