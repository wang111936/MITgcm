#!/usr/bin/env python3
"""Generate deterministic PAPER2024 production inputs for P5-P01 or P5-P02."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import generate_p51_inputs as base


SCHEMA = "MITGCM-BOM-P5-PAPER2024-INPUT-v2"
END_TIME_S = 86_400
OUTPUT_PERIOD_S = 900
ALLOWED_DT_S = (900, 450, 225)
CASES = ("p01", "p02")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="ascii", newline="\n")


def data_text(case_id: str, dt_s: int) -> str:
    del_x = ",".join(["50000."] * base.NX)
    del_y = ",".join(["50000."] * base.NY)
    return f"""# P5-{case_id.upper()} PAPER2024 controlled Cartesian experiment
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
 f0={base.F0_S_INV:.17e},
 beta=0.,
 &
 &PARM02
 cg2dMaxIters=50,
 cg2dTargetResidual=1.E-12,
 &
 &PARM03
 nIter0=0,
 startTime=0.,
 endTime={END_TIME_S}.,
 deltaTmom={dt_s}.,
 deltaTtracer={dt_s}.,
 deltaTClock={dt_s}.,
 pChkptFreq=43200.,
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
 the_run_name='P5-{case_id.upper()}-PAPER2024-DT{dt_s}',
 &
"""


def data_bom_text(dt_s: int) -> str:
    return f""" &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='PAPER2024',
 bomIntegrator='RK4',
 bomDeltaTTarget={dt_s}.,
 bomOutputFreq={OUTPUT_PERIOD_S}.,
 bomPickupFreq=0.,
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
 bomStokesPeriod={dt_s}.,
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
 bomUseBiology=.FALSE.,
 bomUseLand=.FALSE.,
 bomTempSource='NONE',
 bomNSource='NONE',
 &
"""


def write_configuration(output: Path, case_id: str, dt_s: int) -> None:
    write_text(output / "data", data_text(case_id, dt_s))
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
        output / "data.off",
        f""" &OFFLINE_PARM01
 UvelFile='offline_u',
 VvelFile='offline_v',
 ThetFile='offline_theta',
 &
 &OFFLINE_PARM02
 offlineIter0=0,
 deltaToffline={dt_s}.,
 offlineTimeOffset={dt_s / 2:.1f},
 offlineForcingPeriod={dt_s}.,
 offlineForcingCycle=0.,
 offlineLoadPrec=64,
 &
""",
    )
    write_text(
        output / "data.exf",
        f""" &EXF_NML_01
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
 uwindperiod={dt_s}.,
 vwindperiod={dt_s}.,
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
    write_text(output / "data.bom", data_bom_text(dt_s))
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
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--case", choices=CASES, required=True)
    parser.add_argument("--dt-s", type=int, choices=ALLOWED_DT_S, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    repo = args.repo_root.resolve()
    case_id = args.case
    dt_s = args.dt_s
    if case_id == "p01" and dt_s != 900:
        raise ValueError("P5-P01 is frozen at dt=900 s")
    if output.exists():
        raise FileExistsError(f"P5.3 input generator refuses existing output: {output}")
    output.mkdir(parents=True)

    reference = repo / "verification/bom/reference/phase02"
    field_csv = (
        reference / "input_fields_v1.csv"
        if case_id == "p01"
        else repo / "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv"
    )
    particle_csv = reference / "input_particles_v1.csv"
    parameter_toml = reference / "input_parameters_v1.toml"
    fields = base.load_affine_fields(field_csv)
    particles = base.load_particles(particle_csv)
    n_steps = END_TIME_S // dt_s
    endpoint_times = tuple(range(0, END_TIME_S + dt_s, dt_s))
    forcing_times = (*endpoint_times, END_TIME_S + dt_s)
    common_times = tuple(range(0, END_TIME_S + OUTPUT_PERIOD_S, OUTPUT_PERIOD_S))

    write_configuration(output, case_id, dt_s)
    base.write_be64(output / "bathy.bin", [-100.0] * (base.NX * base.NY))
    base.write_be64(output / "uvel_init.bin", base.field_3d(fields[(1, 1)], "u", 0.0))
    base.write_be64(output / "vvel_init.bin", base.field_3d(fields[(1, 2)], "v", 0.0))
    base.write_particle_mds(output, particles)

    ustokes: list[float] = []
    vstokes: list[float] = []
    uwind: list[float] = []
    vwind: list[float] = []
    for record, time_s in enumerate(forcing_times):
        suffix = f"{record:010d}"
        base.write_be64(
            output / f"offline_u.{suffix}", base.field_3d(fields[(1, 1)], "u", time_s)
        )
        base.write_be64(
            output / f"offline_v.{suffix}", base.field_3d(fields[(1, 2)], "v", time_s)
        )
        base.write_be64(
            output / f"offline_theta.{suffix}", base.temperature_3d(time_s)
        )
        ustokes.extend(base.scalar_2d(fields[(2, 1)], time_s))
        vstokes.extend(base.scalar_2d(fields[(2, 2)], time_s))
        uwind.extend(base.scalar_2d(fields[(3, 1)], time_s))
        vwind.extend(base.scalar_2d(fields[(3, 2)], time_s))
    base.write_be64(output / "ustokes.bin", ustokes)
    base.write_be64(output / "vstokes.bin", vstokes)
    base.write_be64(output / "uwind.bin", uwind)
    base.write_be64(output / "vwind.bin", vwind)

    locks = {path.name: sha256(path) for path in (field_csv, particle_csv, parameter_toml)}
    generated = sorted(
        path for path in output.iterdir()
        if path.name not in {"input-manifest.json", "SHA256SUMS"}
    )
    manifest = {
        "schema": SCHEMA,
        "case": f"P5-{case_id.upper()}",
        "equation_mode": "PAPER2024",
        "dimensions": {"nx": base.NX, "ny": base.NY, "nr": base.NR},
        "grid": {
            "coordinate_system": "cartesian_m", "dx_m": base.DX_M,
            "dy_m": base.DY_M, "periodic_x": False, "periodic_y": False,
            "all_wet": True,
        },
        "time": {
            "start_s": 0, "end_s": END_TIME_S, "dt_s": dt_s,
            "n_steps": n_steps, "endpoint_records": len(endpoint_times),
            "forcing_records": len(forcing_times),
            "read_ahead_s": forcing_times[-1],
            "output_period_s": OUTPUT_PERIOD_S,
            "common_times_s": list(common_times),
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
        "particles": [
            {"id": particle_id, "x_m": x, "y_m": y, "status": base.BOM_ALIVE}
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
        f"P5.3 INPUT GENERATION PASS case={case_id} dt={dt_s} steps={n_steps} "
        f"forcing_records={len(forcing_times)} files={len(checksum_paths) + 1}"
    )


if __name__ == "__main__":
    main()
