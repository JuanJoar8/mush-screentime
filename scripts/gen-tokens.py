#!/usr/bin/env python3
"""Generate App/Design/DesignTokens.swift from brand/brand.json.

The chain is one-directional and has no manual step:

    brand/brand.json  ->  App/Design/DesignTokens.swift  ->  screen

A hex literal written by hand in a SwiftUI view is a bug, not a shortcut. If a value
does not exist as a token, add it to brand.json and re-run this.

    python scripts/gen-tokens.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BRAND = ROOT / "brand" / "brand.json"
OUT = ROOT / "App" / "Design" / "DesignTokens.swift"


def camel(name: str) -> str:
    parts = re.split(r"[-_ ]+", name)
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def rgb(hex_str: str):
    h = hex_str.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def main() -> int:
    brand = json.loads(BRAND.read_text(encoding="utf-8"))
    colors = brand["colors"]
    radii = brand["radius"]
    durations = brand["motion"]["durations"]
    typography = brand["typography"]

    lines = [
        "// GENERATED FILE - DO NOT EDIT.",
        "// Source: brand/brand.json   Regenerate: python scripts/gen-tokens.py",
        "//",
        "// Every colour, radius, duration and font in the app comes from here. A hex",
        "// literal in a view is a bug; add the value to brand.json instead.",
        "",
        "import SwiftUI",
        "",
        "public enum Token {",
        "",
        "    // MARK: Colour",
        "",
        "    public enum Color {",
    ]

    for name, hex_str in colors.items():
        r, g, b = rgb(hex_str)
        lines.append(
            f"        /// {hex_str}\n"
            f"        public static let {camel(name)} = SwiftUI.Color("
            f"red: {r:.4f}, green: {g:.4f}, blue: {b:.4f})"
        )

    lines += [
        "    }",
        "",
        "    // MARK: Radius - three values, and only three",
        "",
        "    public enum Radius {",
    ]
    radius_names = ["viewport", "panel", "pill"]
    for name, value in zip(radius_names, radii):
        lines.append(f"        public static let {name}: CGFloat = {value}")

    lines += [
        "    }",
        "",
        "    // MARK: Motion - the fixed scale, no intermediate values",
        "",
        "    public enum Duration {",
    ]
    for name, ms in durations.items():
        lines.append(f"        /// {ms}ms\n        public static let {name}: Double = {ms / 1000:.3f}")

    lines += [
        "    }",
        "",
        "    // MARK: Type",
        "",
        "    public enum Typeface {",
        f'        /// {typography["display"]}, bundled. Variable font; its default',
        "        /// instance is the wide extrabold at a large optical size.",
        '        public static let display = "BricolageGrotesque-96ptExtraBold"',
        "    }",
        "}",
        "",
        "public extension Font {",
        "    /// Display face. Used for the health number and screen titles only.",
        "    static func mushDisplay(_ size: CGFloat) -> Font {",
        "        .custom(Token.Typeface.display, size: size)",
        "    }",
        "",
        "    /// Instrument label: tiny, uppercase, wide-tracked. Pair with .tracking(0.8).",
        "    static func mushLabel() -> Font {",
        "        .system(size: 11, weight: .semibold)",
        "    }",
        "",
        "    /// Numbers that must line up in a column.",
        "    static func mushData(_ size: CGFloat = 14) -> Font {",
        "        .system(size: size, weight: .medium, design: .monospaced)",
        "    }",
        "}",
        "",
    ]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}  ({len(colors)} colours, "
          f"{len(radii)} radii, {len(durations)} durations)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
