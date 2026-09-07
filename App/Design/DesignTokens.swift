// GENERATED FILE - DO NOT EDIT.
// Source: brand/brand.json   Regenerate: python scripts/gen-tokens.py
//
// Every colour, radius, duration and font in the app comes from here. A hex
// literal in a view is a bug; add the value to brand.json instead.

import SwiftUI

public enum Token {

    // MARK: Colour

    public enum Color {
        /// #140B2E
        public static let ground = SwiftUI.Color(red: 0.0784, green: 0.0431, blue: 0.1804)
        /// #0C0620
        public static let groundDeep = SwiftUI.Color(red: 0.0471, green: 0.0235, blue: 0.1255)
        /// #1E1240
        public static let panel = SwiftUI.Color(red: 0.1176, green: 0.0706, blue: 0.2510)
        /// #2A1B55
        public static let panelRaised = SwiftUI.Color(red: 0.1647, green: 0.1059, blue: 0.3333)
        /// #3B2A70
        public static let line = SwiftUI.Color(red: 0.2314, green: 0.1647, blue: 0.4392)
        /// #241552
        public static let viewport = SwiftUI.Color(red: 0.1412, green: 0.0824, blue: 0.3216)
        /// #F1ECFF
        public static let ink = SwiftUI.Color(red: 0.9451, green: 0.9255, blue: 1.0000)
        /// #A093CC
        public static let inkDim = SwiftUI.Color(red: 0.6275, green: 0.5765, blue: 0.8000)
        /// #F1ECFF
        public static let inkOnViewport = SwiftUI.Color(red: 0.9451, green: 0.9255, blue: 1.0000)
        /// #FFFFFF
        public static let specular = SwiftUI.Color(red: 1.0000, green: 1.0000, blue: 1.0000)
        /// #7C5CFA
        public static let primary = SwiftUI.Color(red: 0.4863, green: 0.3608, blue: 0.9804)
        /// #22D3C6
        public static let accent = SwiftUI.Color(red: 0.1333, green: 0.8275, blue: 0.7765)
        /// #34D399
        public static let good = SwiftUI.Color(red: 0.2039, green: 0.8275, blue: 0.6000)
        /// #FBBF24
        public static let warn = SwiftUI.Color(red: 0.9843, green: 0.7490, blue: 0.1412)
        /// #F4436B
        public static let bad = SwiftUI.Color(red: 0.9569, green: 0.2627, blue: 0.4196)
        /// #FFB3C1
        public static let stageCrisp = SwiftUI.Color(red: 1.0000, green: 0.7020, blue: 0.7569)
        /// #E7A7BE
        public static let stageFoggy = SwiftUI.Color(red: 0.9059, green: 0.6549, blue: 0.7451)
        /// #FFC24D
        public static let stageBuzzed = SwiftUI.Color(red: 1.0000, green: 0.7608, blue: 0.3020)
        /// #B08A94
        public static let stageMelting = SwiftUI.Color(red: 0.6902, green: 0.5412, blue: 0.5804)
        /// #7A7391
        public static let stageMush = SwiftUI.Color(red: 0.4784, green: 0.4510, blue: 0.5686)
        /// #4FA8DF
        public static let eyeIris = SwiftUI.Color(red: 0.3098, green: 0.6588, blue: 0.8745)
        /// #1B5E93
        public static let eyeIrisDeep = SwiftUI.Color(red: 0.1059, green: 0.3686, blue: 0.5765)
        /// #0B1A2A
        public static let eyePupil = SwiftUI.Color(red: 0.0431, green: 0.1020, blue: 0.1647)
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
