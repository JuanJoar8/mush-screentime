#!/usr/bin/env python3
"""Assemble host/mockup.html from the template plus the renderer the app actually uses.

    python scripts/build-mockup.py

The creature JS and the stage table are lifted verbatim out of host/console.html rather
than retyped into the template. A hand-copied renderer drifts from the shipping one
within a week, and a review sheet showing a drifted drawing is worse than no review
sheet — it is a green check on something nobody built.

The result is published as an artifact; docs/00-STATUS.md carries the URL. Republishing
is `Artifact` with that URL and this file's output.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONSOLE = ROOT / "host" / "console.html"
TEMPLATE = ROOT / "host" / "mockup.template.html"
OUT = ROOT / "host" / "mockup.html"

console = CONSOLE.read_text(encoding="utf-8")

try:
    a = console.index("  var STAGES = [")
    b = console.index("\n  ];", a) + len("\n  ];")
    c = console.index("  function rgba(hex, a) {")
    d = console.index("  // \u2500\u2500 Engine, ported from BrainHealthEngine")
except ValueError as exc:
    print("FAIL: console.html no longer has the markers this splices on: %s" % exc,
          file=sys.stderr)
    sys.exit(2)

stages, creature = console[a:b], console[c:d].rstrip()

template = TEMPLATE.read_text(encoding="utf-8")
for slot in ("/*__STAGES__*/", "/*__CREATURE_JS__*/"):
    if slot not in template:
        print("FAIL: the template has no %s slot" % slot, file=sys.stderr)
        sys.exit(2)

out = template.replace("/*__STAGES__*/", stages).replace("/*__CREATURE_JS__*/", creature)
OUT.write_text(out, encoding="utf-8")
print("wrote %s  (%d bytes: stage table %d, renderer %d)"
      % (OUT.relative_to(ROOT), len(out), len(stages), len(creature)))
