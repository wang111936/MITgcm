#!/usr/bin/env python3
"""Deterministic verification-only P3 K-nearest-neighbor oracle."""

from __future__ import annotations

import argparse
import itertools
import json
import math
from pathlib import Path
from typing import Any


def pair_distance(a: dict[str, Any], b: dict[str, Any], fixture: dict[str, Any]) -> float:
    dx = float(b["x"]) - float(a["x"])
    dy = float(b["y"]) - float(a["y"])
    period = fixture.get("x_period")
    if period is not None:
        period = float(period)
        dx = math.fmod(dx, period)
        half = 0.5 * period
        if abs(dx) == half:
            raise ValueError("ambiguous half-period pair")
        if dx > half:
            dx -= period
        elif dx < -half:
            dx += period
    geometry = fixture["geometry"]
    if geometry == "cartesian":
        east, north = dx, dy
    elif geometry == "spherical":
        radius = float(fixture["radius"])
        midpoint = math.radians(0.5 * (float(a["y"]) + float(b["y"])))
        cosine = math.cos(midpoint)
        if radius <= 0.0 or abs(cosine) < math.sqrt(math.ulp(1.0)):
            raise ValueError("invalid spherical metric")
        east = radius * cosine * math.radians(dx)
        north = radius * math.radians(dy)
    else:
        raise ValueError(f"unsupported geometry {geometry!r}")
    distance = math.hypot(east, north)
    if not math.isfinite(distance) or distance <= 0.0:
        raise ValueError("invalid pair distance")
    return distance


def evaluate_fixture(fixture: dict[str, Any]) -> dict[str, Any]:
    particles = fixture["particles"]
    if len(particles) < 2:
        raise ValueError("KNN requires at least two particles")
    k_requested = int(fixture["k"])
    if k_requested < 1:
        raise ValueError("K must be positive")
    ids = [int(item["id"]) for item in particles]
    if len(set(ids)) != len(ids) or any(value <= 0 for value in ids):
        raise ValueError("IDs must be unique and positive")
    if any(
        not math.isfinite(float(item[axis]))
        for item in particles
        for axis in ("x", "y")
    ):
        raise ValueError("coordinates must be finite")
    period = fixture.get("x_period")
    if period is not None and (not math.isfinite(float(period)) or float(period) <= 0.0):
        raise ValueError("period must be finite and positive")
    if fixture["geometry"] == "spherical":
        radius = float(fixture["radius"])
        if not math.isfinite(radius) or radius <= 0.0:
            raise ValueError("radius must be finite and positive")
    k_used = min(k_requested, len(particles) - 1)
    records: list[dict[str, Any]] = []
    means: list[float] = []
    for particle in particles:
        candidates = [
            (pair_distance(particle, other, fixture), int(other["id"]))
            for other in particles
            if int(other["id"]) != int(particle["id"])
        ]
        candidates.sort(key=lambda item: (item[0], item[1]))
        selected = candidates[:k_used]
        mean_distance = math.fsum(item[0] for item in selected) / k_used
        means.append(mean_distance)
        records.append(
            {
                "id": int(particle["id"]),
                "neighbors": [item[1] for item in selected],
                "distances": [item[0] for item in selected],
                "mean": mean_distance,
            }
        )
    records.sort(key=lambda item: item["id"])
    ordered_means = sorted(means)
    middle = len(ordered_means) // 2
    if len(ordered_means) % 2:
        natural_length = ordered_means[middle]
    else:
        natural_length = 0.5 * (ordered_means[middle - 1] + ordered_means[middle])
    return {
        "name": fixture["name"],
        "k_requested": k_requested,
        "k_used": k_used,
        "natural_length": natural_length,
        "records": records,
    }


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def run_self_test(fixtures: list[dict[str, Any]]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    saw_rejection = False
    for fixture in fixtures:
        if fixture.get("expect_reject"):
            try:
                evaluate_fixture(fixture)
            except ValueError:
                saw_rejection = True
                continue
            raise AssertionError(f"{fixture['name']} did not reject")
        reference = evaluate_fixture(fixture)
        particles = fixture["particles"]
        permutations = [list(reversed(particles))]
        if len(particles) <= 5:
            permutations.extend(list(order) for order in itertools.islice(itertools.permutations(particles), 12))
        for order in permutations:
            permuted = dict(fixture)
            permuted["particles"] = order
            if canonical_json(evaluate_fixture(permuted)) != canonical_json(reference):
                raise AssertionError(f"slot permutation changed {fixture['name']}")
        results.append(reference)
    if not saw_rejection:
        raise AssertionError("no N<2 rejection fixture")
    by_name = {item["name"]: item for item in results}
    if by_name["line-even"]["natural_length"] != 3.5:
        raise AssertionError("line-even natural length changed")
    odd_expected = 0.5 * (1.0 + math.sqrt(2.0))
    if by_name["distance-tie"]["natural_length"] != odd_expected:
        raise AssertionError("odd natural-length median changed")
    tie = next(item for item in by_name["distance-tie"]["records"] if item["id"] == 500)
    if tie["neighbors"] != [100, 200]:
        raise AssertionError("distance ties are not ordered by global ID")
    if by_name["square-clamp"]["k_used"] != 3:
        raise AssertionError("K>N-1 did not clamp")
    return sorted(results, key=lambda item: item["name"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("fixtures", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    fixtures = json.loads(args.fixtures.read_text(encoding="utf-8"))["fixtures"]
    results = run_self_test(fixtures)
    rendered = json.dumps({"results": results}, indent=2, sort_keys=True, allow_nan=False) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    print(f"P3-K01 PASS: {len(results)} accepted fixtures and deterministic rejection")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
