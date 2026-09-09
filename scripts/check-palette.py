#!/usr/bin/env python3
"""Measure brand/brand.json. Colour claims in prose are not colour claims.

    python scripts/check-palette.py

Two different questions, two different measures - conflating them is how a palette ends
up either unreadable or flattened into a single dimmer:

  * "can text be read on this surface" -> WCAG contrast ratio. AA body is 4.5:1. Every
    `*-ink` role is sized against `ground`, the DARKEST of the four surfaces and so the
    worst case for dark text. Measuring them against `panel` is how four of them once
    shipped at 3.1-3.8:1 with a green check.
  * "are these two fills different colours" -> CIELAB dE. The stage ladder is five
    illustration fills swinging from warm to cool. Demanding they also order by
    luminance would squeeze out the chroma that carries the reading, and would quietly
    undo the deliberate buzzed spike. The first draft of this file did exactly that and
    failed on buzzed, which is how the criterion got fixed instead of the data.

Exit 0 clean, exit 2 with findings.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
C = json.loads((ROOT / "brand" / "brand.json").read_text(encoding="utf-8"))["colors"]

SURFACES = ["ground", "panel", "panel-raised", "viewport"]
LADDER = ["crisp", "foggy", "buzzed", "melting", "mush"]
AA = 4.5
TWIN = 15.0      # dE below which two fills are the same colour to a person
OBJECT = 1.6     # the creature must separate from the band it floats on


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _rgb(hx):
    h = hx.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def luminance(hx):
    r, g, b = (_lin(v) for v in _rgb(hx))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = luminance(C[a]), luminance(C[b])
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def lab(hx):
    r, g, b = (_lin(v) for v in _rgb(hx))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def dE(a, b):
    return math.dist(lab(C[a]), lab(C[b]))


def chroma(k):
    _, a, b = lab(C[k])
    return math.hypot(a, b)


def hue(k):
    _, a, b = lab(C[k])
    return math.degrees(math.atan2(b, a)) % 360


def hue_gap(a, b):
    d = abs(hue(a) - hue(b)) % 360
    return min(d, 360 - d)


bad = []


def need(cond, message):
    if not cond:
        bad.append(message)


# --- Text ---------------------------------------------------------------------------
print("TEXT ON SURFACE (AA body %.1f)" % AA)
print("%-12s %s" % ("", "  ".join("%-10s" % s for s in SURFACES)))
for role in ["ink", "ink-dim", "accent-ink", "good-ink", "warn-ink", "bad-ink"]:
    cells = []
    for s in SURFACES:
        r = ratio(role, s)
        need(r >= AA, "%s on %s is %.2f:1, below AA" % (role, s, r))
        cells.append("%-10s" % ("%.2f" % r))
    print("%-12s %s" % (role, "  ".join(cells)))

# The three semantic fills exist to be filled with, never to be set as text: `good` on a
# panel is 2.5:1. If one of them ever climbs to AA it means somebody muted a fill to win
# an argument it should not be in, and the pill it fills went dead in the process.
#
# `accent` is deliberately NOT in that list. It is a link and a focus ring as much as a
# fill, and being legible is its job - the first version of this check lumped it in with
# the semantics and flagged the brand violet for the crime of being readable.
print(chr(10) + "SATURATED FILLS ARE NOT TEXT (each must stay under AA on every surface)")
for role in ["good", "warn", "bad"]:
    best = max(ratio(role, s) for s in SURFACES)
    print("  %-8s best case anywhere %.2f:1" % (role, best))
    need(best < AA, "%s reads as body text at %.2f:1 - it is a fill, use %s-ink"
         % (role, best, role))

# ...and every one of them, accent included, still has to work as a graphical object. A
# bar whose fill nobody can see against the card behind it is not conveying the number it
# encodes, and 3:1 is the non-text threshold for exactly that. `warn` first ran this
# check at 2.73 and had to be darkened.
print(chr(10) + "AND EVERY FILL IS STILL A GRAPHICAL OBJECT (>= 3.0 against the card)")
for role in ["accent", "good", "warn", "bad"]:
    r = ratio(role, "viewport")
    print("  %-8s %.2f:1 against the viewport" % (role, r))
    need(r >= 3.0, "%s only reaches %.2f:1 against the viewport, too weak to be a component"
         % (role, r))

# --- The creature ---------------------------------------------------------------------
print("\nTHE CREATURE AGAINST THE BAND IT FLOATS ON (>= %.1f)" % OBJECT)
for s in LADDER:
    r = ratio("stage-" + s, "viewport")
    need(r >= OBJECT, "%s only reaches %.2f against the viewport and reads as a stain" % (s, r))
    print("  %-8s %s  %.2f" % (s, C["stage-" + s], r))

print("\nNO TWO RUNGS ARE THE SAME COLOUR (dE >= %.0f)" % TWIN)
worst = min((dE("stage-" + a, "stage-" + b), a, b)
            for i, a in enumerate(LADDER) for b in LADDER[i + 1:])
for a, b in zip(LADDER, LADDER[1:]):
    print("  %-8s -> %-8s dE %5.1f" % (a, b, dE("stage-" + a, "stage-" + b)))
print("  worst pair anywhere: %s/%s at dE %.1f" % (worst[1], worst[2], worst[0]))
need(worst[0] >= TWIN, "%s and %s are twins at dE %.1f" % (worst[1], worst[2], worst[0]))

# --- What the colour itself says --------------------------------------------------------
print("\nTHE LADDER IS A WALK INTO THE ROOM")
for s in LADDER:
    k = "stage-" + s
    print("  %-8s chroma %5.1f   hue %5.1f   gap to the room %5.1f"
          % (s, chroma(k), hue(k), hue_gap(k, "ground")))
print("  %-8s chroma %5.1f   hue %5.1f" % ("(room)", chroma("ground"), hue("ground")))

walk = [r for r in LADDER if r != "buzzed"]
need(chroma("stage-crisp") >= max(chroma("stage-" + r) for r in walk),
     "crisp is not the most chromatic rung of the walk; alive means owning a colour")
need(chroma("stage-mush") <= min(chroma("stage-" + r) for r in LADDER),
     "mush is not the least chromatic rung, so nothing is dissolving into anything")
need(chroma("stage-buzzed") > chroma("stage-crisp"),
     "buzzed must out-chroma crisp - the spike is the point, and flattening it turns the "
     "five stages back into five positions of one dimmer")
need(hue_gap("stage-mush", "ground") <= 30,
     "mush hue is %.0f off the room; it has to rot INTO the background, not beside it"
     % hue_gap("stage-mush", "ground"))
need(hue_gap("stage-crisp", "ground") >= 90,
     "crisp sits only %.0f from the room's hue; that gap is what reads as alive"
     % hue_gap("stage-crisp", "ground"))

# --- The room is Opal, not a tinted grey -------------------------------------------------
print("\nTHE ROOM HAS REAL CHROMA, NOT A HINT OF ONE")
for k in ["ground", "panel", "panel-raised", "viewport", "accent"]:
    print("  %-14s chroma %5.1f" % (k, chroma(k)))
need(chroma("ground") >= 18,
     "ground chroma is %.1f - that is a grey with a rumour of violet, not Opal"
     % chroma("ground"))
need(chroma("accent") >= 60,
     "accent chroma is %.1f - the brand violet has to be a colour, not a slate"
     % chroma("accent"))

if bad:
    print("\n%d FINDING(S)" % len(bad))
    for b in bad:
        print("  - " + b)
    sys.exit(2)
print("\nthe palette measures the way brand.json says it does")
