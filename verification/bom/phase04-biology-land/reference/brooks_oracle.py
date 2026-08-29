#!/usr/bin/env python3
"""Independent high-precision oracle for P4.1 Brooks records."""

from __future__ import annotations

import argparse
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 90
D = Decimal


def evaluate(t: D, n: D, mu: D = D("0.2"), mort: D = D("0.01")):
    tmin, tmax, kn = D("10"), D("40"), D("2")
    topt = (tmin + tmax) / D(2)
    if t == tmin or t == tmax:
        tf = D(0)
    elif tmin < t < topt:
        ratio = (t - topt) / (t - tmin)
        tf = (-D("0.5") * ratio * ratio).exp()
    elif t == topt:
        tf = D(1)
    elif topt < t < tmax:
        ratio = (t - topt) / (t - tmax)
        tf = (-D("0.5") * ratio * ratio).exp()
    else:
        tf = D(0)
    nsafe = max(n, D(0))
    nf = nsafe / (kn + nsafe)
    return float(tf), float(nf), float(mu * tf * nf - mort)


CASES = {
    "t-below": (D("9"), D("2")),
    "t-min": (D("10"), D("2")),
    "t-lower": (D("17.5"), D("2")),
    "t-opt": (D("25"), D("2")),
    "t-upper": (D("32.5"), D("2")),
    "t-max": (D("40"), D("2")),
    "t-above": (D("41"), D("2")),
    "n-negative": (D("25"), D("-1")),
    "n-zero": (D("25"), D("0")),
    "n-small": (D("25"), D("0.000001")),
    "n-kn": (D("25"), D("2")),
    "n-large": (D("25"), D("1000000")),
    "n-extreme": (D("25"), D("1e300")),
}


def compare(actual_path: Path) -> None:
    actual = {}
    for line in actual_path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) != 5 or parts[0] != "P41-BROOKS-RECORD":
            continue
        actual[parts[1]] = tuple(float(value) for value in parts[2:])
    if set(actual) != set(CASES):
        raise SystemExit(f"record labels differ: {sorted(actual)}")
    for label, inputs in CASES.items():
        expected = evaluate(*inputs)
        for index, (got, want) in enumerate(zip(actual[label], expected)):
            tolerance = 256.0 * 2.220446049250313e-16 * max(1.0, abs(want))
            if abs(got - want) > tolerance:
                raise SystemExit(
                    f"{label} component {index}: got {got!r}, expected {want!r}"
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("actual", type=Path)
    compare(parser.parse_args().actual)


if __name__ == "__main__":
    main()
