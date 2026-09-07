// GENERATED FILE - DO NOT EDIT.
// Source: brand/brand.json   Regenerate: python scripts/gen-tokens.py
//
// Every colour, radius, duration and font in the app comes from here. A hex
// literal in a view is a bug; add the value to brand.json instead.

import SwiftUI

public enum Token {

    // MARK: Colour

    public enum Color {
        /// #1B2016
        public static let ground = SwiftUI.Color(red: 0.1059, green: 0.1255, blue: 0.0863)
        /// #242A1D
        public static let panel = SwiftUI.Color(red: 0.1412, green: 0.1647, blue: 0.1137)
        /// #2E3625
        public static let panelRaised = SwiftUI.Color(red: 0.1804, green: 0.2118, blue: 0.1451)
        /// #3A4230
        public static let line = SwiftUI.Color(red: 0.2275, green: 0.2588, blue: 0.1882)
        /// #E7E4D3
        public static let viewport = SwiftUI.Color(red: 0.9059, green: 0.8941, blue: 0.8275)
        /// #EDEFE6
        public static let ink = SwiftUI.Color(red: 0.9294, green: 0.9373, blue: 0.9020)
        /// #8E9880
        public static let inkDim = SwiftUI.Color(red: 0.5569, green: 0.5961, blue: 0.5020)
        /// #1B2016
        public static let inkOnViewport = SwiftUI.Color(red: 0.1059, green: 0.1255, blue: 0.0863)
        /// #F2789F
        public static let primary = SwiftUI.Color(red: 0.9490, green: 0.4706, blue: 0.6235)
        /// #F2B705
        public static let accent = SwiftUI.Color(red: 0.9490, green: 0.7176, blue: 0.0196)
        /// #6E9E4A
        public static let good = SwiftUI.Color(red: 0.4314, green: 0.6196, blue: 0.2902)
        /// #F2B705
        public static let warn = SwiftUI.Color(red: 0.9490, green: 0.7176, blue: 0.0196)
        /// #C8503A
        public static let bad = SwiftUI.Color(red: 0.7843, green: 0.3137, blue: 0.2275)
        /// #F2789F
        public static let stageCrisp = SwiftUI.Color(red: 0.9490, green: 0.4706, blue: 0.6235)
        /// #D9A0AE
        public static let stageFoggy = SwiftUI.Color(red: 0.8510, green: 0.6275, blue: 0.6824)
        /// #F2B705
        public static let stageBuzzed = SwiftUI.Color(red: 0.9490, green: 0.7176, blue: 0.0196)
        /// #B58A6A
        public static let stageMelting = SwiftUI.Color(red: 0.7098, green: 0.5412, blue: 0.4157)
        /// #7C7A6B
        public static let stageMush = SwiftUI.Color(red: 0.4863, green: 0.4784, blue: 0.4196)
    }

    // MARK: Radius - three values, and only three

    public enum Radius {
        public static let viewport: CGFloat = 28
        public static let panel: CGFloat = 12
        public static let pill: CGFloat = 999
    }

    // MARK: Motion - the fixed scale, no intermediate values

    public enum Duration {
        /// 80ms
        public static let instant: Double = 0.080
        /// 160ms
        public static let fast: Double = 0.160
        /// 240ms
        public static let base: Double = 0.240
        /// 360ms
        public static let slow: Double = 0.360
    }

    // MARK: Type

    public enum Typeface {
        /// Bricolage Grotesque, bundled. Variable font; its default
        /// instance is the wide extrabold at a large optical size.
        public static let display = "BricolageGrotesque-96ptExtraBold"
    }
}

public extension Font {
    /// Display face. Used for the health number and screen titles only.
    static func mushDisplay(_ size: CGFloat) -> Font {
        .custom(Token.Typeface.display, size: size)
    }

    /// Instrument label: tiny, uppercase, wide-tracked. Pair with .tracking(0.8).
    static func mushLabel() -> Font {
        .system(size: 11, weight: .semibold)
    }

    /// Numbers that must line up in a column.
    static func mushData(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
