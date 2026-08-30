#!/usr/bin/env python3
"""Generate the frozen P5-L01 controlled 30-day PAPER2024 inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import generate_p51_inputs as base


DT_S = 3600
DAY_S = 86_400
END_S = 30 * DAY_S
SPLIT_S = 15 * DAY_S
SPLIT_ITER = SPLIT_S // DT_S
N_CYCLE = DAY_S // DT_S
SCALE = 0.02
IDS = (1001, 1002, 1003)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="ascii", newline="\n")


def scaled(values: list[float]) -> list[float]:
    return [SCALE * value for value in values]


def data_text(name: str, niter0: int, start_s: int, end_s: int) -> str:
    del_x = ",".join(["50000."] * base.NX)
    del_y = ",".join(["50000."] * base.NY)
    return f"""# P5-L01 controlled periodic 30-day experiment: {name}
 &PARM01
 tRef=20.,20.,
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
 nIter0={niter0},
 startTime={start_s}.,
 endTime={end_s}.,
 deltaTmom={DT_S}.,
 deltaTtracer={DT_S}.,
 deltaTClock={DT_S}.,
 pChkptFreq={DAY_S}.,
 chkptFreq=0.,
 dumpFreq=0.,
 monitorFreq={DAY_S}.,
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
 hydrogThetaFile='theta.bin',
 the_run_name='P5-L01-CONTROLLED-30DAY',
 &
"""


def data_bom_text() -> str:
    return f""" &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='PAPER2024',
 bomIntegrator='RK4',
 bomDeltaTTarget={DT_S}.,
 bomOutputFreq={DT_S}.,
 bomPickupFreq=0.,
 bomSeed=20260831,
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
 bomStokesPeriod={DT_S}.,
 bomStokesRepCycle={DAY_S}.,
 bomStokesInScale=1.,
 bomStokesFilePrec=64,
 bomWetWeightMin=0.999999,
 bomAdvCFL=0.5,
 bomMaxHop=8,
 bomInitGlobalLimit=1000,
 bomCheckEverySubstep=.TRUE.,
 bomSpringL=100.,
 &
 &BOM_PARM03
 bomUseBiology=.TRUE.,
 bomUseLand=.TRUE.,
 bomTempSource='THETA',
 bomNSource='FILES',
 bomBiologyMissingPolicy='STOP',
 bomMuMaxDay=0.,
 bomMortDay=0.,
 bomKN=1.,
 bomTMin=10.,
 bomTMax=30.,
 bomS0=1.,
 bomSMin=0.5,
 bomSMax=1.5,
 bomBirthMaxTry=4,
 bomNFile='nutrient.bin',
 bomNStartTime=0.,
 bomNPeriod={DT_S}.,
 bomNRepCycle={DAY_S}.,
 bomNInScale=1.,
 bomNFilePrec=64,
 bomEventFile='p54_events',
 bomP4SourceHead='0000000000000000000000000000000000000000',
 &
"""


def write_configuration(output: Path, name: str, niter0: int, start_s: int, end_s: int) -> None:
    write_text(output / "data", data_text(name, niter0, start_s, end_s))
    write_text(output / "data.pkg", """ &PACKAGES
 useOffLine=.TRUE.,
 useEXF=.TRUE.,
 useDiagnostics=.FALSE.,
 useMNC=.FALSE.,
 useBOM=.TRUE.,
 &
""")
    write_text(output / "data.off", f""" &OFFLINE_PARM01
 UvelFile='offline_u',
 VvelFile='offline_v',
 ThetFile='offline_theta',
 &
 &OFFLINE_PARM02
 offlineIter0=0,
 deltaToffline={DT_S}.,
 offlineTimeOffset={DT_S / 2:.1f},
 offlineForcingPeriod={DT_S}.,
 offlineForcingCycle={DAY_S}.,
 offlineLoadPrec=64,
 &
""")
    write_text(output / "data.exf", f""" &EXF_NML_01
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
 uwindperiod={DT_S}.,
 vwindperiod={DT_S}.,
 uwindRepCycle={DAY_S}.,
 vwindRepCycle={DAY_S}.,
 &
 &EXF_NML_03
 exf_inscal_uwind=1.,
 exf_inscal_vwind=1.,
 uwindconst=0.,
 vwindconst=0.,
 &
 &EXF_NML_04
 &
""")
    write_text(output / "data.bom", data_bom_text())
    write_text(output / "eedata", """ &EEPARMS
 nTx=1,
 nTy=1,
 &
""")


def write_case(output: Path, repo: Path, name: str, niter0: int, start_s: int, end_s: int) -> None:
    output.mkdir()
    reference = repo / "verification/bom/reference/phase02"
    fields = base.load_affine_fields(reference / "input_fields_v1.csv")
    particles = base.load_particles(reference / "input_particles_v1.csv")
    write_configuration(output, name, niter0, start_s, end_s)
    base.write_be64(output / "bathy.bin", [-100.0] * (base.NX * base.NY))
    base.write_be64(output / "theta.bin", [20.0] * (base.NX * base.NY * base.NR))
    base.write_be64(output / "uvel_init.bin", scaled(base.field_3d(fields[(1, 1)], "u", 0.0)))
    base.write_be64(output / "vvel_init.bin", scaled(base.field_3d(fields[(1, 2)], "v", 0.0)))
    base.write_particle_mds(output, particles)

    ustokes: list[float] = []
    vstokes: list[float] = []
    uwind: list[float] = []
    vwind: list[float] = []
    nutrient: list[float] = []
    for record in range(N_CYCLE):
        physical_time = record * DT_S
        control_time = (DAY_S / (2.0 * math.pi)) * math.sin(2.0 * math.pi * physical_time / DAY_S)
        # OFFLINE periodic files are addressed one-based; the cycle endpoint
        # (record 24) carries the exact time-zero field used across the wrap.
        suffix = f"{(record if record > 0 else N_CYCLE):010d}"
        base.write_be64(output / f"offline_u.{suffix}",
                        scaled(base.field_3d(fields[(1, 1)], "u", control_time)))
        base.write_be64(output / f"offline_v.{suffix}",
                        scaled(base.field_3d(fields[(1, 2)], "v", control_time)))
        base.write_be64(output / f"offline_theta.{suffix}",
                        [20.0] * (base.NX * base.NY * base.NR))
        ustokes.extend(scaled(base.scalar_2d(fields[(2, 1)], control_time)))
        vstokes.extend(scaled(base.scalar_2d(fields[(2, 2)], control_time)))
        uwind.extend(scaled(base.scalar_2d(fields[(3, 1)], control_time)))
        vwind.extend(scaled(base.scalar_2d(fields[(3, 2)], control_time)))
        nutrient.extend([1.0] * (base.NX * base.NY))
    base.write_be64(output / "ustokes.bin", ustokes)
    base.write_be64(output / "vstokes.bin", vstokes)
    base.write_be64(output / "uwind.bin", uwind)
    base.write_be64(output / "vwind.bin", vwind)
    base.write_be64(output / "nutrient.bin", nutrient)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo-root", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    repo = args.repo_root.resolve()
    if output.exists():
        raise FileExistsError(f"P5-L01 refuses existing output: {output}")
    output.mkdir(parents=True)
    write_case(output / "continuous", repo, "continuous", 0, 0, END_S)
    write_case(output / "part1", repo, "part1", 0, 0, SPLIT_S)
    write_case(output / "part2", repo, "part2", SPLIT_ITER, SPLIT_S, END_S)
    manifest = {
        "schema": "MITGCM-BOM-P5-L01-input-v1",
        "equation_mode": "PAPER2024",
        "layout": "MPI4",
        "dt_s": DT_S,
        "end_s": END_S,
        "steps": END_S // DT_S,
        "split_iteration": SPLIT_ITER,
        "forcing_cycle_s": DAY_S,
        "forcing_records": N_CYCLE,
        "forcing_scale": SCALE,
        "trajectory_period_s": DT_S,
        "pickup_period_s": DAY_S,
        "ids": list(IDS),
        "biology": {"enabled": True, "growth_per_day": 0.0, "mortality_per_day": 0.0,
                     "expected_total_mass": 3.0},
        "land": {"enabled": True, "wet_cells": base.NX * base.NY},
        "case_input_sha256": {
            name: {path.name: sha256(path) for path in sorted((output / name).iterdir())}
            for name in ("continuous", "part1", "part2")
        },
    }
    write_text(output / "expected.json", json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("P5-L01 INPUT GENERATION PASS days=30 hourly_steps=720 cycle_records=24 cases=3")


if __name__ == "__main__":
    main()
