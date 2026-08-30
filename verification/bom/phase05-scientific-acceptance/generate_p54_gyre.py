#!/usr/bin/env python3
"""Create byte-audited P5-O01 inputs from the standard baroclinic gyre."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path


NX = NY = 62
PARTICLES = (
    (4001, 10.5, 30.5),
    (4002, 30.5, 45.5),
    (4003, 50.5, 60.5),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="ascii", newline="\n")


def write_particles(output: Path) -> None:
    records = [(1.0, 8.0, float(len(PARTICLES)), 1.0, 1.0, 64.0, 0.0, 0.0)]
    for particle_id, x_coord, y_coord in PARTICLES:
        records.append((float(particle_id >> 32), float(particle_id & 0xFFFFFFFF),
                        x_coord, y_coord, 0.0, 1.0, 0.0, 0.0))
    values = tuple(value for record in records for value in record)
    (output / "bom_particles.data").write_bytes(struct.pack(f">{len(values)}d", *values))
    write_text(
        output / "bom_particles.meta",
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


def data_bom() -> str:
    return """ &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='PAPER2024',
 bomIntegrator='RK4',
 bomDeltaTTarget=1200.,
 bomOutputFreq=1200.,
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
 bomAlpha=0.,
 bomTauDays=0.0103,
 bomR=0.823,
 bomSigma=0.,
 bomLeewayWindCoeff=0.,
 bomWindSource='NONE',
 bomStokesSource='NONE',
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
 bomBiologyMissingPolicy='STOP',
 bomEventFile='p54_gyre_events',
 bomP4SourceHead='0000000000000000000000000000000000000000',
 &
"""


def bom_on_packages(stock: str) -> str:
    require("useMNC=.TRUE." in stock and "useDiagnostics=.TRUE." in stock,
            "unexpected standard data.pkg")
    require("useBOM" not in stock, "standard case unexpectedly enables BOM")
    return stock.replace(" useDiagnostics=.TRUE.,\n", " useDiagnostics=.TRUE.,\n useBOM=.TRUE.,\n")


def archival_data(stock: str) -> str:
    old = " pChkptFreq=622080000.,"
    require(stock.count(old) == 1, "unexpected standard permanent-pickup setting")
    return stock.replace(old, " pChkptFreq=1200.,")


def audit_seed_bathymetry(stock_input: Path) -> None:
    payload = (stock_input / "bathy.bin").read_bytes()
    require(len(payload) == NX * NY * 4, "standard bathymetry byte count")
    values = struct.unpack(f">{NX * NY}f", payload)
    for particle_id, x_coord, y_coord in PARTICLES:
        i_global = int(x_coord - (-1.0)) + 1
        j_global = int(y_coord - 14.0) + 1
        require(3 <= i_global <= NX - 2 and 3 <= j_global <= NY - 2,
                f"particle {particle_id} not two cells inside the wall")
        require(values[(j_global - 1) * NX + i_global - 1] < 0.0,
                f"particle {particle_id} is not wet")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("standard_input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    standard_input = args.standard_input.resolve()
    output = args.output.resolve()
    require(standard_input.is_dir(), "standard input directory missing")
    if output.exists():
        raise FileExistsError(f"P5-O01 refuses existing output: {output}")
    audit_seed_bathymetry(standard_input)

    stock = output / "stock-input"
    shutil.copytree(standard_input, stock)
    original = {path.name: sha256(path) for path in sorted(standard_input.iterdir()) if path.is_file()}
    copied = {path.name: sha256(path) for path in sorted(stock.iterdir()) if path.is_file()}
    require(original == copied, "standard input copy is not byte-identical")

    stock_packages = (stock / "data.pkg").read_text(encoding="ascii")
    stock_data = (stock / "data").read_text(encoding="ascii")
    for label, bom_enabled in (("mpi4-off", False), ("mpi4-on", True), ("serial-on", True)):
        target = output / label
        shutil.copytree(stock, target)
        write_text(target / "data", archival_data(stock_data))
        if bom_enabled:
            write_text(target / "data.pkg", bom_on_packages(stock_packages))
            write_text(target / "data.bom", data_bom())
            write_particles(target)

    manifest = {
        "schema": "MITGCM-BOM-P5-O01-input-v1",
        "standard_input": str(standard_input),
        "standard_sha256": original,
        "ocean_steps": 10,
        "delta_t_s": 1200,
        "derived_output_only_change": "pChkptFreq=1200 seconds",
        "particles": [
            {"id": item[0], "x": item[1], "y": item[2]} for item in PARTICLES
        ],
        "layouts": {"mpi4-off": [2, 2], "mpi4-on": [2, 2], "serial-on": [1, 1]},
    }
    write_text(output / "expected.json", json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    write_text(
        output / "SHA256SUMS",
        "".join(
            f"{sha256(path)}  {path.relative_to(output).as_posix()}\n"
            for path in sorted(output.rglob("*"))
            if path.is_file() and path.name != "SHA256SUMS"
        ),
    )
    print(f"P5-O01 INPUT GENERATION PASS files={len(original)} particles={len(PARTICLES)}")


if __name__ == "__main__":
    main()
