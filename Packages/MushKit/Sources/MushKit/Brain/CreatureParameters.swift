import Foundation

// The creature's parameter table.
//
// It lives in the domain package rather than beside the drawing for the same reason
// `GemShape` does: the five stages are the product, and "each stage is identifiable
// rather than merely darker" is a claim worth asserting rather than writing down.
// `CreatureParameterTests` holds those assertions — including the one brand.json states
// as an anti-slop rule, that no stage may be distinguishable by its colour alone.
//
// The drawing stays in the app target. This file is only the numbers.

/// Drawn props, not tuned parameters.
///
/// The five stages used to differ only by degree — a little more sag, a little less
/// gloss — and a spectrum of degrees reads as one creature in five moods rather than as
/// two conditions. These are the things that are either there or not, and they are what
/// makes a stage *identifiable* instead of merely darker.
///
/// They split the ladder in two on purpose. Sparkle belongs to healing, drip and crack
/// belong to rot, and `buzzed` gets the pair that says overstimulated rather than
/// damaged: a spiral pupil and a bead of sweat.
public struct Motifs: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Four-pointed stars around the head. Healing only.
    public static let sparkle = Motifs(rawValue: 1 << 0)
    /// Hypnotised pupils. The one drawing everybody already reads as brainrot.
    public static let spiral = Motifs(rawValue: 1 << 1)
    /// A bead at the temple.
    public static let sweat = Motifs(rawValue: 1 << 2)
    /// Teardrops hanging off the lower contour: the body itself going.
    public static let drip = Motifs(rawValue: 1 << 3)
    /// Fissures across the surface that are not gyri.
    public static let crack = Motifs(rawValue: 1 << 4)
}

/// Everything the drawing reads off a stage.
///
/// The five used to differ only by degree, and a spectrum of degrees reads as one
/// creature in five moods. They are now two conditions: fold density falls from sixteen
/// a side to two, healing carries sparkles and rot carries drips and cracks, and no two
/// stages share an arm height. `CreatureParameterTests` asserts all of that, because a
/// stage that is only distinguishable by its colour is the failure this table exists to
/// prevent — and brand.json lists it as an anti-slop rule.
public struct CreatureParameters: Equatable, Sendable {
    /// Brow rotation. Negative raises the outer end (alert); positive raises the inner
    /// end, which is the universal shape of worry.
    public var browTilt: CGFloat
    /// How far the brows sit above the glasses.
    public var browLift: CGFloat
    /// Eyelid coverage, 0...1.
    public var lid: CGFloat
    /// Eye opening, where 1 is neutral. `buzzed` goes above 1.
    public var open: CGFloat
    /// Downward slump.
    public var sag: CGFloat
    /// It widens as it loses structure.
    public var spread: CGFloat
    /// Sheen strength: how present the flat white highlight strokes are, and how far the
    /// blush carries. A dulled brain does not merely darken — it stops catching light.
    public var sheen: CGFloat
    /// How much iris shows around the pupil. Low is a blown pupil; high is a startled
    /// ring of colour. `buzzed` is the high one.
    public var pupil: CGFloat
    /// Mouth. Above ~0.15 it opens; below, it is a single stroked curve, and negative
    /// turns it down.
    public var mouth: CGFloat
    /// Arm height, per side, and they are never equal.
    ///
    /// Zero is a shoulder-height arm, positive hangs, negative raises — so `crisp` waves
    /// with one and rests the other, and `mush` lets both hang dead. Symmetry is the
    /// single thing that makes a drawn figure look switched off, which is why no stage
    /// gets the same number twice.
    public var armLeft: CGFloat
    public var armRight: CGFloat
    /// How far a fold stands proud of the surface around it, 1 being firm tissue.
    ///
    /// This is the *material* half of the smooth-brain reading, where `foldsPerSide` is
    /// the count half. A stage can lose folds and still look like a healthy brain with
    /// fewer of them; losing turgor is what makes the remaining ones read as smeared. It
    /// scales the offset of every groove and crest in the drawing, so at `mush` the folds
    /// are still there and have simply stopped standing up.
    public var turgor: CGFloat
    /// How tight the specular highlight is: wet tissue against a matte dome.
    ///
    /// Separate from `sheen`, which is how *bright* the light is. Gloss is how *sharp* it
    /// is, and the two come apart at `buzzed`: an overstimulated brain is not a dull one,
    /// so it stays wet and shining while `foggy`, one rung better, has already gone soft.
    /// That is the parameter that keeps the ladder from being a dimmer switch.
    public var gloss: CGFloat
    /// High-frequency tremor. Only `buzzed` has one.
    public var jitter: CGFloat
    /// Seconds between blinks. A duller creature blinks more slowly.
    public var blinkInterval: Double
    /// Rings of folds, and folds per ring.
    ///
    /// **This is the main signal now.** A brain losing its convolutions is the metaphor
    /// the internet already reaches for — "smooth brain" — so fold density is not
    /// texture, it is the reading. Sixteen folds a side at `crisp`, two at `mush`.
    public var foldRings: Int
    public var foldsPerRing: Int
    /// What is drawn on and around it that is not the creature itself.
    public var motifs: Motifs

    /// Total folds drawn on one hemisphere. The single number that says how far down the
    /// ladder a stage is, and the one axis `CreatureParameterTests` requires to be
    /// monotonic.
    public var foldsPerSide: Int { foldRings * foldsPerRing }

    public static func forStage(_ stage: BrainStage) -> CreatureParameters {
        switch stage {
        case .crisp:
            .init(browTilt: -0.16, browLift: 0.10, lid: 0.00, open: 1.00, sag: 0.00,
                  spread: 0.00, sheen: 1.00, pupil: 0.10, mouth: 0.85, armLeft: 0.34, armRight: -1.90,
                  turgor: 1.00, gloss: 1.00,
                  jitter: 0.000, blinkInterval: 3.2,
                  foldRings: 4, foldsPerRing: 4, motifs: [.sparkle])
        case .foggy:
            .init(browTilt: 0.12, browLift: 0.06, lid: 0.18, open: 0.92, sag: 0.05,
                  spread: 0.04, sheen: 0.66, pupil: 0.16, mouth: 0.22, armLeft: 0.38, armRight: 0.46,
                  turgor: 0.72, gloss: 0.46,
                  jitter: 0.000, blinkInterval: 4.6,
                  foldRings: 3, foldsPerRing: 4, motifs: [])
        case .buzzed:
            .init(browTilt: -0.36, browLift: 0.14, lid: 0.00, open: 1.18, sag: 0.02,
                  spread: 0.03, sheen: 0.82, pupil: 0.42, mouth: -0.18, armLeft: -0.38, armRight: -0.26,
                  turgor: 0.86, gloss: 0.78,
                  jitter: 0.050, blinkInterval: 1.9,
                  foldRings: 3, foldsPerRing: 3, motifs: [.spiral, .sweat])
        case .melting:
            .init(browTilt: 0.32, browLift: 0.04, lid: 0.40, open: 0.82, sag: 0.13,
                  spread: 0.10, sheen: 0.32, pupil: 0.14, mouth: -0.46, armLeft: 0.62, armRight: 0.76,
                  turgor: 0.44, gloss: 0.20,
                  jitter: 0.000, blinkInterval: 6.4,
                  foldRings: 2, foldsPerRing: 2, motifs: [.drip, .sweat])
        case .mush:
            .init(browTilt: 0.44, browLift: 0.02, lid: 0.60, open: 0.72, sag: 0.22,
                  spread: 0.16, sheen: 0.14, pupil: 0.10, mouth: -0.62, armLeft: 0.94, armRight: 0.86,
                  turgor: 0.22, gloss: 0.06,
                  jitter: 0.000, blinkInterval: 8.8,
                  foldRings: 1, foldsPerRing: 2, motifs: [.drip, .crack])
        }
    }
}
