#!/usr/bin/env python3
"""Validate and summarize P3.5 fixed-density per-rank metrics."""

from __future__ import annotations

import argparse
import math
from collections import defaultdict
from pathlib import Path
from statistics import fmean


FIELD_NAMES = (
    "n_owner",
    "owner_records",
    "ghost_records",
    "nonempty_cells",
    "comparisons",
    "directed",
    "undirected",
    "max_neighbors",
    "packets_sent",
    "packets_received",
    "bytes_sent",
    "bytes_received",
)


def parse_metric(line: str) -> dict[str, int | float | str] | None:
    marker = line.find("P35METRIC")
    if marker < 0:
        return None
    fields = line[marker:].split()
    if len(fields) != 17 or fields[0] != "P35METRIC":
        raise ValueError(f"invalid P35METRIC record: {line.rstrip()}")
    record: dict[str, int | float | str] = {
        "rank": int(fields[1]),
        "geometry": fields[2],
        "side": int(fields[3]),
    }
    for name, value in zip(FIELD_NAMES, fields[4:16], strict=True):
        record[name] = int(value)
    record["seconds"] = float(fields[16])
    return record


def percentile95(values: list[float]) -> float:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(0.95 * len(ordered)) - 1)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("--expected-ranks", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    grouped: dict[tuple[str, int], list[dict[str, int | float | str]]]
    grouped = defaultdict(list)
    for log in args.logs:
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            record = parse_metric(line)
            if record is not None:
                grouped[(str(record["geometry"]), int(record["side"]))].append(record)

    expected_keys = {(geometry, side) for geometry in ("CART", "SPHR") for side in (16, 32, 64)}
    if set(grouped) != expected_keys:
        raise SystemExit(f"metric groups differ: {sorted(grouped)}")

    rows: list[dict[str, int | float | str]] = []
    ratios: dict[str, list[tuple[int, float, float]]] = defaultdict(list)
    for key in sorted(grouped):
        geometry, side = key
        records = grouped[key]
        ranks = sorted(int(record["rank"]) for record in records)
        if ranks != list(range(args.expected_ranks)):
            raise SystemExit(f"{key}: ranks differ: {ranks}")
        owners = sum(int(record["owner_records"]) for record in records)
        ghosts = sum(int(record["ghost_records"]) for record in records)
        comparisons = sum(int(record["comparisons"]) for record in records)
        directed = sum(int(record["directed"]) for record in records)
        undirected = sum(int(record["undirected"]) for record in records)
        packets_sent = sum(int(record["packets_sent"]) for record in records)
        packets_received = sum(int(record["packets_received"]) for record in records)
        bytes_sent = sum(int(record["bytes_sent"]) for record in records)
        bytes_received = sum(int(record["bytes_received"]) for record in records)
        expected_owners = side * side
        expected_edges = 2 * side * (side - 1)
        if owners != expected_owners:
            raise SystemExit(f"{key}: owners={owners}, expected={expected_owners}")
        if directed != 2 * expected_edges or undirected != expected_edges:
            raise SystemExit(f"{key}: directed/undirected balance failure")
        if max(int(record["max_neighbors"]) for record in records) != 4:
            raise SystemExit(f"{key}: maximum degree is not four")
        if packets_sent != packets_received or bytes_sent != bytes_received:
            raise SystemExit(f"{key}: communication balance failure")
        comparison_ratio = comparisons / owners
        boundary_incidents = 2 * side * (8 + 8 - 2)
        ghost_ratio = ghosts / boundary_incidents
        if comparison_ratio > 16.0:
            raise SystemExit(f"{key}: comparisons/owner exceeds 16")
        if ghost_ratio > 8.0:
            raise SystemExit(f"{key}: ghosts/boundary-owner exceeds 8")
        seconds = [float(record["seconds"]) for record in records]
        mean_seconds = fmean(seconds)
        ratios[geometry].append((side, comparison_ratio, ghost_ratio))
        rows.append(
            {
                "geometry": geometry,
                "side": side,
                "ranks": args.expected_ranks,
                "owners": owners,
                "ghosts": ghosts,
                "comparisons": comparisons,
                "comparisons_per_owner": comparison_ratio,
                "ghosts_per_boundary_owner": ghost_ratio,
                "time_min_s": min(seconds),
                "time_mean_s": mean_seconds,
                "time_p95_s": percentile95(seconds),
                "time_max_s": max(seconds),
                "load_imbalance": max(seconds) / mean_seconds if mean_seconds else 1.0,
            }
        )

    for geometry, values in ratios.items():
        values.sort()
        first_comparison = values[0][1]
        first_ghost = values[0][2]
        for side, comparison_ratio, ghost_ratio in values[1:]:
            if comparison_ratio > first_comparison + 0.25:
                raise SystemExit(
                    f"{geometry}-{side}: comparisons/owner grows beyond tolerance"
                )
            if ghost_ratio > first_ghost + 0.25:
                raise SystemExit(
                    f"{geometry}-{side}: ghosts/boundary-owner grows beyond tolerance"
                )

    columns = (
        "geometry",
        "side",
        "ranks",
        "owners",
        "ghosts",
        "comparisons",
        "comparisons_per_owner",
        "ghosts_per_boundary_owner",
        "time_min_s",
        "time_mean_s",
        "time_p95_s",
        "time_max_s",
        "load_imbalance",
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as stream:
        stream.write("\t".join(columns) + "\n")
        for row in rows:
            stream.write("\t".join(str(row[column]) for column in columns) + "\n")
    print("P3_FIXED_DENSITY_ANALYSIS_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
