// GENERATED FILE - DO NOT EDIT.
// Source: brand/brand.json   Regenerate: python scripts/gen-tokens.py
//
// Every colour, radius, duration and font in the app comes from here. A hex
// literal in a view is a bug; add the value to brand.json instead.

import SwiftUI

public enum Token {

    // MARK: Colour

    public enum Color {
        /// #B9B3C9
        public static let ground = SwiftUI.Color(red: 0.7255, green: 0.7020, blue: 0.7882)
        /// #8F88A6
        public static let groundDeep = SwiftUI.Color(red: 0.5608, green: 0.5333, blue: 0.6510)
        /// #CBC6D8
        public static let panel = SwiftUI.Color(red: 0.7961, green: 0.7765, blue: 0.8471)
        /// #DEDAE8
        public static let panelRaised = SwiftUI.Color(red: 0.8706, green: 0.8549, blue: 0.9098)
        /// #A29ABA
        public static let line = SwiftUI.Color(red: 0.6353, green: 0.6039, blue: 0.7294)
        /// #F1EFF4
        public static let viewport = SwiftUI.Color(red: 0.9451, green: 0.9373, blue: 0.9569)
        /// #211D33
        public static let ink = SwiftUI.Color(red: 0.1294, green: 0.1137, blue: 0.2000)
        /// #474160
        public static let inkDim = SwiftUI.Color(red: 0.2784, green: 0.2549, blue: 0.3765)
        /// #211D33
        public static let inkOnViewport = SwiftUI.Color(red: 0.1294, green: 0.1137, blue: 0.2000)
        /// #2E2030
        public static let shadeAnchor = SwiftUI.Color(red: 0.1804, green: 0.1255, blue: 0.1882)
        /// #FFFFFF
        public static let specular = SwiftUI.Color(red: 1.0000, green: 1.0000, blue: 1.0000)
        /// #FF5A38
        public static let subsurface = SwiftUI.Color(red: 1.0000, green: 0.3529, blue: 0.2196)
        /// #616B52
        public static let necrotic = SwiftUI.Color(red: 0.3804, green: 0.4196, blue: 0.3216)
        /// #2A63D6
        public static let accent = SwiftUI.Color(red: 0.1647, green: 0.3882, blue: 0.8392)
        /// #173A82
        public static let accentInk = SwiftUI.Color(red: 0.0902, green: 0.2275, blue: 0.5098)
        /// #22B23E
        public static let good = SwiftUI.Color(red: 0.1333, green: 0.6980, blue: 0.2431)
        /// #0A4E1D
        public static let goodInk = SwiftUI.Color(red: 0.0392, green: 0.3059, blue: 0.1137)
        /// #E28C13
        public static let warn = SwiftUI.Color(red: 0.8863, green: 0.5490, blue: 0.0745)
        /// #5E3704
        public static let warnInk = SwiftUI.Color(red: 0.3686, green: 0.2157, blue: 0.0157)
        /// #E23A5E
        public static let bad = SwiftUI.Color(red: 0.8863, green: 0.2275, blue: 0.3686)
        /// #7E152C
        public static let badInk = SwiftUI.Color(red: 0.4941, green: 0.0824, blue: 0.1725)
        /// #F9BFA2
        public static let stageCrisp = SwiftUI.Color(red: 0.9765, green: 0.7490, blue: 0.6353)
        /// #EEAE99
        public static let stageFoggy = SwiftUI.Color(red: 0.9333, green: 0.6824, blue: 0.6000)
        /// #F0994F
        public static let stageBuzzed = SwiftUI.Color(red: 0.9412, green: 0.6000, blue: 0.3098)
        /// #C09189
        public static let stageMelting = SwiftUI.Color(red: 0.7529, green: 0.5686, blue: 0.5373)
        /// #9C8B92
        public static let stageMush = SwiftUI.Color(red: 0.6118, green: 0.5451, blue: 0.5725)
        /// #3E86C4
        public static let eyeIris = SwiftUI.Color(red: 0.2431, green: 0.5255, blue: 0.7686)
        /// #1B4D77
        public static let eyeIrisDeep = SwiftUI.Color(red: 0.1059, green: 0.3020, blue: 0.4667)
        /// #17131F
        public static let eyePupil = SwiftUI.Color(red: 0.0902, green: 0.0745, blue: 0.1216)
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
