#!/usr/bin/env python3
"""Catch the one workflow mistake that costs a whole round trip.

GitHub rejects an invalid workflow *before any job starts*, so a broken file produces no
build, no log and no clue — just "this run likely failed because of a workflow file
issue". That happened here when a `\\n` escape written by a generator became a real
newline inside a shell string, pushing the rest of the line out of its `run: |` block.

If PyYAML is installed this defers to it and checks the whole file. If it is not, it
falls back to detecting exactly that failure: a continuation line inside a block scalar
that is indented less than the block requires and does not begin a new YAML key.

Usage:  python scripts/check-workflow.py [path ...]
Exit 0 clean, 1 with findings.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

BLOCK_KEY = re.compile(r"^(?P<indent>\s*)(-\s+)?(run|if|shell):\s*[|>][-+]?\s*$")
YAML_KEY = re.compile(r"^\s*(-\s+)?[A-Za-z_][\w.\-]*\s*:")
LIST_ITEM = re.compile(r"^\s*-\s")


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def check(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")

    try:
        import yaml  # type: ignore
    except ImportError:
        pass
    else:
        try:
            yaml.safe_load(text)
            return []
        except Exception as error:  # noqa: BLE001 - the message is the finding
            return [f"{path}: {error}"]

    findings: list[str] = []
    lines = text.split("\n")
    block_indent: int | None = None
    content_indent: int | None = None

    for number, line in enumerate(lines, start=1):
        if not line.strip():
            continue

        if block_indent is None:
            match = BLOCK_KEY.match(line)
            if match:
                block_indent = indent_of(line)
                content_indent = None
            continue

        current = indent_of(line)

        # First content line sets the block's required indentation.
        if content_indent is None:
            if current > block_indent:
                content_indent = current
                continue
            block_indent = None
            continue

        if current >= content_indent:
            continue

        # Dedented. Either the block ended properly, or a line escaped it.
        #
        # A comment at or above the parent's indentation ends the block too — that is how
        # every step in this repo is introduced, and treating it as an escape would make
        # the checker cry wolf on a correct file.
        ends_block = (
            YAML_KEY.match(line) or LIST_ITEM.match(line) or line.lstrip().startswith("#")
        )
        if ends_block and current <= block_indent:
            block_indent = None
            content_indent = None
            match = BLOCK_KEY.match(line)
            if match:
                block_indent = indent_of(line)
            continue

        findings.append(
            f"{path}:{number}: line escaped its `run: |` block "
            f"(indent {current}, block needs {content_indent}): {line.strip()[:72]!r}"
        )
        block_indent = None
        content_indent = None

    return findings


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv[1:]] or sorted(
        Path(".github/workflows").glob("*.yml")
    )
    if not targets:
        print("no workflow files found")
        return 1

    findings: list[str] = []
    for path in targets:
        findings.extend(check(path))

    if findings:
        for finding in findings:
            print(finding)
        return 1

    print(f"workflows ok ({len(targets)} file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
