// GENERATED FILE - DO NOT EDIT.
// Source: brand/brand.json   Regenerate: python scripts/gen-tokens.py
//
// Every colour, radius, duration and font in the app comes from here. A hex
// literal in a view is a bug; add the value to brand.json instead.

import SwiftUI

public enum Token {

    // MARK: Colour

    public enum Color {
        /// #B8AED5
        public static let ground = SwiftUI.Color(red: 0.7216, green: 0.6824, blue: 0.8353)
        /// #7D6AAF
        public static let groundDeep = SwiftUI.Color(red: 0.4902, green: 0.4157, blue: 0.6863)
        /// #CBC4E3
        public static let panel = SwiftUI.Color(red: 0.7961, green: 0.7686, blue: 0.8902)
        /// #DCD7EF
        public static let panelRaised = SwiftUI.Color(red: 0.8627, green: 0.8431, blue: 0.9373)
        /// #9D91C0
        public static let line = SwiftUI.Color(red: 0.6157, green: 0.5686, blue: 0.7529)
        /// #EBE8F8
        public static let viewport = SwiftUI.Color(red: 0.9216, green: 0.9098, blue: 0.9725)
        /// #19122B
        public static let ink = SwiftUI.Color(red: 0.0980, green: 0.0706, blue: 0.1686)
        /// #463B63
        public static let inkDim = SwiftUI.Color(red: 0.2745, green: 0.2314, blue: 0.3882)
        /// #19122B
        public static let inkOnViewport = SwiftUI.Color(red: 0.0980, green: 0.0706, blue: 0.1686)
        /// #1B0F29
        public static let shadeAnchor = SwiftUI.Color(red: 0.1059, green: 0.0588, blue: 0.1608)
        /// #FFFFFF
        public static let specular = SwiftUI.Color(red: 1.0000, green: 1.0000, blue: 1.0000)
        /// #FFFFFF
        public static let onFill = SwiftUI.Color(red: 1.0000, green: 1.0000, blue: 1.0000)
        /// #FF5A38
        public static let subsurface = SwiftUI.Color(red: 1.0000, green: 0.3529, blue: 0.2196)
        /// #566647
        public static let necrotic = SwiftUI.Color(red: 0.3373, green: 0.4000, blue: 0.2784)
        /// #5931ED
        public static let accent = SwiftUI.Color(red: 0.3490, green: 0.1922, blue: 0.9294)
        /// #3D19A9
        public static let accentInk = SwiftUI.Color(red: 0.2392, green: 0.0980, blue: 0.6627)
        /// #1B8D54
        public static let good = SwiftUI.Color(red: 0.1059, green: 0.5529, blue: 0.3294)
        /// #0A4C2E
        public static let goodInk = SwiftUI.Color(red: 0.0392, green: 0.2980, blue: 0.1804)
        /// #BF7008
        public static let warn = SwiftUI.Color(red: 0.7490, green: 0.4392, blue: 0.0314)
        /// #623304
        public static let warnInk = SwiftUI.Color(red: 0.3843, green: 0.2000, blue: 0.0157)
        /// #D52050
        public static let bad = SwiftUI.Color(red: 0.8353, green: 0.1255, blue: 0.3137)
        /// #821230
        public static let badInk = SwiftUI.Color(red: 0.5098, green: 0.0706, blue: 0.1882)
        /// #F9A676
        public static let stageCrisp = SwiftUI.Color(red: 0.9765, green: 0.6510, blue: 0.4627)
        /// #D6A295
        public static let stageFoggy = SwiftUI.Color(red: 0.8392, green: 0.6353, blue: 0.5843)
        /// #FB8823
        public static let stageBuzzed = SwiftUI.Color(red: 0.9843, green: 0.5333, blue: 0.1373)
        /// #AC7277
        public static let stageMelting = SwiftUI.Color(red: 0.6745, green: 0.4471, blue: 0.4667)
        /// #7D738C
        public static let stageMush = SwiftUI.Color(red: 0.4902, green: 0.4510, blue: 0.5490)
        /// #3E86C4
        public static let eyeIris = SwiftUI.Color(red: 0.2431, green: 0.5255, blue: 0.7686)
        /// #1B4D77
        public static let eyeIrisDeep = SwiftUI.Color(red: 0.1059, green: 0.3020, blue: 0.4667)
        /// #15111D
        public static let eyePupil = SwiftUI.Color(red: 0.0824, green: 0.0667, blue: 0.1137)
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
