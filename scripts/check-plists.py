#!/usr/bin/env python3
"""Every app extension's Info.plist carries the keys the embed step needs.

Written after MushBlocker's plist shipped without CFBundleIdentifier. The build failed
with:

    error: Embedded binary's bundle identifier is not prefixed with the parent app's
    bundle identifier.

which names neither the missing key nor the target that is missing it. Without
CFBundleIdentifier the bundle takes a default that has no relation to the app's, and the
message you get describes the symptom two steps downstream.

There are seven targets in this project and there will be more - the remaining Feed
Quarantine layers each want one. This costs a second and runs anywhere.

    python scripts/check-plists.py
"""

import plistlib
import sys
from pathlib import Path

# Every one of these is load-bearing at build or install time, and every one of them
# fails with a message that points somewhere else when it is absent.
REQUIRED = {
    "CFBundleIdentifier": "the embed step rejects a bundle not prefixed with the app's",
    "CFBundleExecutable": "the extension has no binary to launch",
    "CFBundlePackageType": "iOS will not recognise the bundle as an extension",
    "CFBundleVersion": "App Store validation and TestFlight both refuse it",
    "CFBundleShortVersionString": "same, and it is what the user sees",
    "NSExtension": "an app extension with no extension point is a folder",
}

root = Path(__file__).resolve().parent.parent
plists = sorted(root.glob("Extensions/*/Info.plist"))

if not plists:
    print("FAIL: no extension Info.plist found — has the layout changed?", file=sys.stderr)
    sys.exit(2)

problems = 0
for path in plists:
    with path.open("rb") as handle:
        data = plistlib.load(handle)

    missing = [key for key in REQUIRED if key not in data]
    name = path.parent.name

    if missing:
        problems += 1
        print(f"FAIL  {name}")
        for key in missing:
            print(f"        missing {key} — {REQUIRED[key]}")
    else:
        point = data["NSExtension"].get("NSExtensionPointIdentifier", "(none)")
        print(f"ok    {name}  {point}")

if problems:
    print(f"\n{problems} extension(s) would fail at the embed step.", file=sys.stderr)
    sys.exit(2)

print(f"\n{len(plists)} extension plists complete.")
