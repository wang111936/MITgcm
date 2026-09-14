#!/usr/bin/env python3
"""Inject uncommitted physical/meta tails into a copied archive fixture."""

from __future__ import annotations

import re
import sys
from pathlib import Path

RECORD_BYTES = 64 * 8


def fail(message: str) -> None:
    raise SystemExit(f"P5.6 ORPHAN INJECT FAIL: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: inject_orphan_tail.py ARCHIVE_DIR")
    directory = Path(sys.argv[1]).resolve()
    index_paths = sorted(directory.glob("bom_trajectories.s*.index.data"))
    if len(index_paths) != 1:
        fail(f"expected one index, found {len(index_paths)}")
    index_path = index_paths[0]
    segment = index_path.name[: -len(".index.data")]
    tile_paths = sorted(
        directory.glob(
            f"{segment}.[0-9][0-9][0-9].[0-9][0-9][0-9].data"
        )
    )
    if not tile_paths:
        fail("no tile data member found")
    tile_path = tile_paths[0]
    tile_meta = tile_path.with_suffix(".meta")
    meta_text = tile_meta.read_text(encoding="ascii")
    match = re.search(r"(nrecords\s*=\s*\[\s*)(\d+)(\s*\])", meta_text)
    if match is None:
        fail("tile meta lacks nrecords")
    old_records = int(match.group(2))
    updated = (
        meta_text[: match.start()]
        + match.group(1)
        + str(old_records + 2)
        + match.group(3)
        + meta_text[match.end() :]
    )
    with tile_path.open("ab") as stream:
        stream.write(bytes(2 * RECORD_BYTES))
    tile_meta.write_text(updated, encoding="ascii")
    with index_path.open("ab") as stream:
        stream.write(bytes(RECORD_BYTES))
    print(
        "P5.6 ORPHAN INJECT PASS "
        f"tile={tile_path.name} tile_records={old_records + 2} index_tail=1"
    )


if __name__ == "__main__":
    main()
