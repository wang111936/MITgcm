#!/usr/bin/env python3
"""Generate the frozen P5-F01 production-system input bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
from typing import Iterable


NX, NY, NR = 8, 6, 2
DX_M = DY_M = 1000.0
PARTICLE_FIELDS = 8
BOM_ALIVE = 1
SOURCE_HEAD = "0" * 40
CASES = ("spring", "birth", "cancel", "death", "coast", "combined")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="ascii", newline="\n")


def write_be64(path: Path, values: Iterable[float]) -> None:
    sequence = tuple(values)
    path.write_bytes(struct.pack(f">{len(sequence)}d", *sequence))


def split_id(particle_id: int) -> tuple[float, float]:
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def write_particles(path: Path, particles: tuple[tuple[int, float, float], ...]) -> None:
    records: list[tuple[float, ...]] = [
        (1.0, 8.0, float(len(particles)), 1.0, 1.0, 64.0, 0.0, 0.0)
    ]
    for particle_id, x_m, y_m in particles:
        hi, lo = split_id(particle_id)
        records.append((hi, lo, x_m, y_m, 0.0, float(BOM_ALIVE), 0.0, 0.0))
    write_be64(path / "bom_particles.data", (value for row in records for value in row))
    write_text(
        path / "bom_particles.meta",
        f""" nDims = [   3 ];
 dimList = [
     1,    1,    1,
     1,    1,    1,
     8,    1,    8
 ];
 dataprec = [ 'float64' ];
 nrecords = [ {len(records):5d} ];
 timeStepNumber = [          0 ];
 nFlds = [    1 ];
 fldList = {{
 'BOMV0001'
 }};
""",
    )


def data_text(case: str, dt_s: int, end_s: int, pickup_s: int) -> str:
    del_x = ",".join(["1000."] * NX)
    del_y = ",".join(["1000."] * NY)
    return f"""# MITGCM-BOM P5-F01 manufactured production case: {case}
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
 f0=0.,
 beta=0.,
 &
 &PARM02
 cg2dMaxIters=50,
 cg2dTargetResidual=1.E-12,
 &
 &PARM03
 nIter0=0,
 startTime=0.,
 endTime={end_s}.,
 deltaTmom={dt_s}.,
 deltaTtracer={dt_s}.,
 deltaTClock={dt_s}.,
 pChkptFreq={pickup_s}.,
 chkptFreq=0.,
 dumpFreq=0.,
 monitorFreq={dt_s}.,
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
 uVelInitFile='uvel.bin',
 vVelInitFile='vvel.bin',
 hydrogThetaFile='theta.bin',
 the_run_name='MITGCM-BOM-P5-F01-{case.upper()}',
 &
"""


def inactive_p4() -> str:
    return """ bomUseBiology=.FALSE.,
 bomUseLand=.FALSE.,
 bomTempSource='NONE',
 bomNSource='NONE',
 bomBiologyMissingPolicy='STOP',
 bomEventFile='p54_events',
 bomP4SourceHead='0000000000000000000000000000000000000000',
"""


def active_p4(
    *, mu_day: float, mort_day: float, spring_l: float, s_min: float = 0.5,
    s_max: float = 1.5,
) -> str:
    return f""" bomUseBiology=.TRUE.,
 bomUseLand=.TRUE.,
 bomTempSource='THETA',
 bomNSource='FILES',
 bomBiologyMissingPolicy='STOP',
 bomMuMaxDay={mu_day:.17g},
 bomMortDay={mort_day:.17g},
 bomKN=1.,
 bomTMin=10.,
 bomTMax=30.,
 bomS0=1.,
 bomSMin={s_min:.17g},
 bomSMax={s_max:.17g},
 bomBirthMaxTry=4,
 bomNFile='nutrient.bin',
 bomNStartTime=0.,
 bomNPeriod=100.,
 bomNRepCycle=0.,
 bomNInScale=1.,
 bomNFilePrec=64,
 bomEventFile='p54_events',
 bomP4SourceHead='0000000000000000000000000000000000000000',
"""


def land_only_p4() -> str:
    return """ bomUseBiology=.FALSE.,
 bomUseLand=.TRUE.,
 bomTempSource='NONE',
 bomNSource='NONE',
 bomBiologyMissingPolicy='STOP',
 bomEventFile='p54_events',
 bomP4SourceHead='0000000000000000000000000000000000000000',
"""


def bom_text(case: str, dt_s: int) -> str:
    spring = case in ("spring", "combined")
    biology = case in ("birth", "cancel", "death", "combined")
    if case == "birth":
        p4 = active_p4(mu_day=1000.0, mort_day=0.0, spring_l=100.0)
    elif case == "cancel":
        p4 = active_p4(mu_day=1000.0, mort_day=0.0, spring_l=10000.0)
    elif case == "death":
        p4 = active_p4(mu_day=0.0, mort_day=1000.0, spring_l=100.0)
    elif case == "combined":
        p4 = active_p4(
            mu_day=1000.0, mort_day=100.0, spring_l=100.0,
            s_min=0.9, s_max=1.4,
        )
    elif case == "coast":
        p4 = land_only_p4()
    else:
        p4 = inactive_p4()
    max_particles = 8 if biology else (3 if case == "spring" else 2)
    spring_l = 100.0
    spring_l_biology = 10000.0 if case == "cancel" else spring_l
    wet_weight_min = 0.49 if case == "coast" else 0.999999
    adv_cfl = 1.0 if case == "coast" else 0.9
    law = "EBOMB" if spring else "NONE"
    neighbor = "CUTOFF" if spring else "NONE"
    output = dt_s
    return f""" &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='PAPER2024',
 bomIntegrator='RK4',
 bomDeltaTTarget={dt_s}.,
 bomOutputFreq={output}.,
 bomPickupFreq=0.,
 bomSeed=20260831,
 bomMaxParticles={max_particles},
 bomInitialIter=0,
 bomInitialFile='bom_particles',
 bomSpringLaw='{law}',
 bomNeighborPolicy='{neighbor}',
 &
 &BOM_PARM02
 bomCurrentPolicy='EULERIAN',
 bomAlpha=0.,
 bomTauDays=0.000011574074074074074,
 bomR=1.,
 bomSigma=0.,
 bomLeewayWindCoeff=0.,
 bomWindSource='NONE',
 bomStokesSource='NONE',
 bomWetWeightMin={wet_weight_min:.17g},
 bomAdvCFL={adv_cfl:.17g},
 bomMaxHop=8,
 bomInitGlobalLimit=1000,
 bomCheckEverySubstep=.TRUE.,
 bomSpringL={spring_l_biology:.17g},
 bomHookeK=0.,
 bomSpringA={0.001 if spring else 0.0:.17g},
 bomSpringDelta={25.0 if spring else 0.0:.17g},
 bomNeighborCutoff={350.0 if spring else 0.0:.17g},
 bomPairDistanceMin={1.0e-6 if spring else 0.0:.17g},
 bomSpringCFL=1.,
 bomRaftDiagnostics={'.TRUE.' if spring else '.FALSE.'},
 &
 &BOM_PARM03
{p4} &
"""


def case_definition(case: str) -> dict[str, object]:
    if case == "spring":
        return {
            "dt_s": 20,
            "end_s": 80,
            "pickup_s": 0,
            "particles": ((101, 2500.0, 2500.0), (202, 2700.0, 2500.0),
                          (303, 2500.0, 2700.0)),
            "u_m_s": 0.0,
            "dry_cell": None,
            "expected_events": {},
        }
    if case in ("birth", "cancel", "death"):
        event_type = {"birth": 1, "death": 2, "cancel": 5}[case]
        return {
            "dt_s": 100,
            "end_s": 100,
            "pickup_s": 0,
            "particles": ((1001, 1500.0, 1500.0),),
            "u_m_s": 0.0,
            "dry_cell": None,
            "expected_events": {str(event_type): 1},
        }
    if case == "coast":
        return {
            "dt_s": 100,
            "end_s": 100,
            "pickup_s": 0,
            "particles": ((2001, 2500.0, 2500.0), (2002, 7500.0, 4500.0)),
            "u_m_s": 10.0,
            "dry_cell": (4, 3),
            "expected_events": {"3": 1, "4": 1},
        }
    if case == "combined":
        return {
            "dt_s": 100,
            "end_s": 100,
            "pickup_s": 100,
            "particles": ((3001, 1500.0, 1500.0), (3002, 4500.0, 4500.0)),
            "u_m_s": 0.0,
            "dry_cell": None,
            "expected_events": {"1": 1, "2": 1},
        }
    raise ValueError(case)


def write_case(root: Path, case: str) -> None:
    spec = case_definition(case)
    output = root / case
    output.mkdir(parents=True)
    dt_s = int(spec["dt_s"])
    end_s = int(spec["end_s"])
    pickup_s = int(spec["pickup_s"])
    particles = spec["particles"]
    require(isinstance(particles, tuple), "particle fixture type")

    write_text(output / "data", data_text(case, dt_s, end_s, pickup_s))
    write_text(output / "data.bom", bom_text(case, dt_s))
    write_text(
        output / "data.pkg",
        """ &PACKAGES
 useDiagnostics=.FALSE.,
 useMNC=.FALSE.,
 useOffLine=.FALSE.,
 useEXF=.FALSE.,
 useBOM=.TRUE.,
 &
""",
    )
    write_text(output / "eedata", """ &EEPARMS
 nTx=1,
 nTy=1,
 &
""")
    write_particles(output, particles)

    bathy = [-100.0] * (NX * NY)
    dry_cell = spec["dry_cell"]
    if dry_cell is not None:
        i_cell, j_cell = dry_cell
        bathy[(j_cell - 1) * NX + i_cell - 1] = 0.0
    write_be64(output / "bathy.bin", bathy)

    u_value = float(spec["u_m_s"])
    write_be64(output / "uvel.bin", [u_value] * (NX * NY * NR))
    write_be64(output / "vvel.bin", [0.0] * (NX * NY * NR))
    theta = [20.0] * (NX * NY * NR)
    if case == "combined":
        theta[(5 - 1) * NX + (5 - 1)] = 10.0
    write_be64(output / "theta.bin", theta)
    # GET_PERIODIC_INTERVAL needs the exact endpoint plus one read-ahead
    # record at the final model step: t=0, 100 and 200 s.
    write_be64(output / "nutrient.bin", [1.0] * (3 * NX * NY))

    mu_day = 0.0
    mort_day = 0.0
    s_min = 0.5
    s_max = 1.5
    if case in ("birth", "cancel"):
        mu_day = 1000.0
    elif case == "death":
        mort_day = 1000.0
    elif case == "combined":
        mu_day = 1000.0
        mort_day = 100.0
        s_min = 0.9
        s_max = 1.4
    rate_birth = mu_day / 86400.0 * 0.5 - mort_day / 86400.0
    rate_cold = -mort_day / 86400.0
    expected = {
        "schema": "MITGCM-BOM-P5-F01-input-v1",
        "case": case,
        "dimensions": {"nx": NX, "ny": NY, "nr": NR},
        "dt_s": dt_s,
        "end_s": end_s,
        "particles": [
            {"id": item[0], "x_m": item[1], "y_m": item[2], "s0": 1.0}
            for item in particles
        ],
        "expected_event_counts": spec["expected_events"],
        "biology": {
            "mu_day": mu_day,
            "mort_day": mort_day,
            "s_min": s_min,
            "s_max": s_max,
            "warm_rate_s_inv": rate_birth,
            "warm_s_trial": 1.0 + rate_birth * dt_s,
            "cold_rate_s_inv": rate_cold,
            "cold_s_trial": 1.0 + rate_cold * dt_s,
        },
        "spring": {
            "law": "EBOMB" if case in ("spring", "combined") else "NONE",
            "tau_s": 1.0,
            "natural_length_m": 100.0 if case != "cancel" else 10000.0,
            "amplitude_s_inv2": 0.001 if case in ("spring", "combined") else 0.0,
            "delta_m": 25.0 if case in ("spring", "combined") else 0.0,
            "cutoff_m": 350.0 if case in ("spring", "combined") else 0.0,
        },
        "coast": {
            "u_m_s": u_value,
            "dry_cell_1_based": list(dry_cell) if dry_cell else None,
        },
        "source_head": SOURCE_HEAD,
    }
    write_text(output / "expected.json", json.dumps(expected, indent=2, sort_keys=True) + "\n")
    files = sorted(path for path in output.iterdir() if path.name != "SHA256SUMS")
    write_text(
        output / "SHA256SUMS",
        "".join(f"{sha256(path)}  {path.name}\n" for path in files),
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--case", choices=(*CASES, "all"), default="all")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"P5.4 refuses existing output: {output}")
    output.mkdir(parents=True)
    selected = CASES if args.case == "all" else (args.case,)
    for case in selected:
        write_case(output, case)
    require(all(math.isfinite(value) for value in (DX_M, DY_M)), "grid finite")
    print(f"P5.4 INPUT GENERATION PASS cases={len(selected)} root={output}")


if __name__ == "__main__":
    main()
