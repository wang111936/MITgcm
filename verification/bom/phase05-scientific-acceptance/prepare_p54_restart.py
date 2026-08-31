#!/usr/bin/env python3
"""Prepare the frozen P5-R01 continuous/split directory matrix."""

from __future__ import annotations

import argparse
import json
import shutil
import struct
from pathlib import Path


LAYOUTS = ("serial", "mpi2", "mpi4")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    require(text.count(old) == 1, f"{label}: expected exactly one {old!r}")
    return text.replace(old, new)


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="ascii", newline="\n")


def prepare_case_j(base: Path, continuous: Path, part1: Path, part2: Path) -> None:
    for target in (continuous, part1, part2):
        shutil.copytree(base, target)
    original = (base / "data").read_text(encoding="ascii")
    first = replace_once(original, " endTime=86400.,", " endTime=43200.,", "case-j part1")
    second = replace_once(original, " nIter0=0,", " nIter0=48,", "case-j part2")
    second = replace_once(second, " startTime=0.,", " startTime=43200.,", "case-j part2")
    write_text(part1 / "data", first)
    write_text(part2 / "data", second)


def prepare_combined_base(base: Path, target: Path) -> None:
    shutil.copytree(base, target)
    data = (target / "data").read_text(encoding="ascii")
    data = replace_once(data, " endTime=100.,", " endTime=200.,", "combined duration")
    data = replace_once(data, " pChkptFreq=100.,", " pChkptFreq=200.,", "combined pickup")
    write_text(target / "data", data)
    data_bom = (target / "data.bom").read_text(encoding="ascii")
    data_bom = replace_once(data_bom, " bomOutputFreq=100.,", " bomOutputFreq=200.,",
                            "combined output")
    data_bom = replace_once(data_bom, " bomMuMaxDay=1000,", " bomMuMaxDay=2800,",
                            "combined two-step growth")
    data_bom = replace_once(data_bom, " bomMortDay=100,", " bomMortDay=1000,",
                            "combined two-step mortality")
    data_bom = replace_once(data_bom, " bomSMin=0.90000000000000002,", " bomSMin=0.1,",
                            "combined two-step death threshold")
    write_text(target / "data.bom", data_bom)
    nutrient = target / "nutrient.bin"
    payload = nutrient.read_bytes()
    record_bytes = 8 * 6 * 8
    require(len(payload) == 3 * record_bytes, "combined nutrient input record count")
    values = struct.unpack(">144d", payload)
    second_step_value = 5.0 / 9.0
    extended = (*values[:96], *([second_step_value] * 96))
    nutrient.write_bytes(struct.pack(">192d", *extended))


def prepare_combined(base: Path, continuous: Path, part1: Path, part2: Path) -> None:
    prepare_combined_base(base, continuous)
    prepare_combined_base(base, part1)
    prepare_combined_base(base, part2)
    first = (part1 / "data").read_text(encoding="ascii")
    first = replace_once(first, " endTime=200.,", " endTime=100.,", "combined part1")
    first = replace_once(first, " pChkptFreq=200.,", " pChkptFreq=100.,", "combined part1")
    write_text(part1 / "data", first)
    second = (part2 / "data").read_text(encoding="ascii")
    second = replace_once(second, " nIter0=0,", " nIter0=1,", "combined part2")
    second = replace_once(second, " startTime=0.,", " startTime=100.,", "combined part2")
    write_text(part2 / "data", second)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-j", type=Path, required=True)
    parser.add_argument("--combined", type=Path, required=True)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"P5-R01 refuses existing output: {output}")
    output.mkdir(parents=True)
    for layout in LAYOUTS:
        prepare_case_j(
            args.case_j.resolve(),
            output / f"casej-{layout}-continuous",
            output / f"casej-{layout}-part1",
            output / f"casej-{layout}-part2",
        )
        prepare_combined(
            args.combined.resolve(),
            output / f"combined-{layout}-continuous",
            output / f"combined-{layout}-part1",
            output / f"combined-{layout}-part2",
        )
    manifest = {
        "schema": "MITGCM-BOM-P5-R01-input-v1",
        "layouts": list(LAYOUTS),
        "case_j": {"steps": 96, "split_iteration": 48, "dt_s": 900},
        "combined": {
            "steps": 2, "split_iteration": 1, "dt_s": 100,
            "trajectory_period_s": 200,
            "split_before_continuous_event_flush": True,
            "first_step_rates_day": {"warm_net": 400, "cold_net": -1000},
            "second_step_warm_net_day": 0,
        },
    }
    write_text(output / "expected.json", json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("P5-R01 INPUT PREPARATION PASS cases=2 layouts=3 directories=18")


if __name__ == "__main__":
    main()
