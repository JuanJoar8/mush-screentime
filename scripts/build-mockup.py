#!/usr/bin/env python3
"""Assemble the host pages from their templates plus the renderer the app actually uses.

    python scripts/build-mockup.py

Two outputs, one splice:

    host/mockup.template.html  ->  host/mockup.html   the character review sheet
    host/app.template.html     ->  host/app.html      the app, navigable in a browser

The creature JS and the stage table are lifted verbatim out of host/console.html rather
than retyped into either template. A hand-copied renderer drifts from the shipping one
within a week, and a review sheet showing a drifted drawing is worse than no review
sheet - it is a green check on something nobody built. The same is true of a mockup
somebody is using to judge the app.

The review sheet is published as an artifact; docs/00-STATUS.md carries the URL.
Republishing is `Artifact` with that URL and this file's output.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONSOLE = ROOT / "host" / "console.html"

TARGETS = [
    (ROOT / "host" / "mockup.template.html", ROOT / "host" / "mockup.html"),
    (ROOT / "host" / "app.template.html", ROOT / "host" / "app.html"),
]

console = CONSOLE.read_text(encoding="utf-8")

try:
    a = console.index("  var STAGES = [")
    b = console.index("\n  ];", a) + len("\n  ];")
    c = console.index("  function rgba(hex, a) {")
    d = console.index("  // ── Engine, ported from BrainHealthEngine")
except ValueError as exc:
    print("FAIL: console.html no longer has the markers this splices on: %s" % exc,
          file=sys.stderr)
    sys.exit(2)

stages, creature = console[a:b], console[c:d].rstrip()

failed = False
for template_path, out_path in TARGETS:
    if not template_path.exists():
        print("FAIL: %s is missing" % template_path.relative_to(ROOT), file=sys.stderr)
        failed = True
        continue

    template = template_path.read_text(encoding="utf-8")
    missing = [slot for slot in ("/*__STAGES__*/", "/*__CREATURE_JS__*/")
               if slot not in template]
    if missing:
        print("FAIL: %s has no %s slot" % (template_path.name, ", ".join(missing)),
              file=sys.stderr)
        failed = True
        continue

    out = template.replace("/*__STAGES__*/", stages).replace("/*__CREATURE_JS__*/", creature)
    out_path.write_text(out, encoding="utf-8")
    print("wrote %s  (%d bytes: stage table %d, renderer %d)"
          % (out_path.relative_to(ROOT), len(out), len(stages), len(creature)))

sys.exit(2 if failed else 0)
