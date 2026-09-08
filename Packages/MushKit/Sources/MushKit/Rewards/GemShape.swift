import Foundation

/// The geometry of one gem, derived from its id.
///
/// It lives in the domain package rather than beside the view for one reason: "every gem
/// in the catalogue is visibly distinct" is a claim about a reward the user collects, and
/// a claim like that should be tested, not asserted in a doc comment.
///
/// The first version derived the side count from `5 + seed % 4` and gave twelve gems four
/// shapes — five of them heptagons with identical facets. On the shelf they read as the
/// same badge printed twelve times, which is the one thing a collectible cannot be.
///
/// **Two independent mixes, not two moduli of one sum.** The obvious fix — take
/// `sides = 5 + sum % 6` and `facet = sum % 3` from the same number — does not work,
/// because 6 and 3 share a factor: the two axes move together and twelve gems collapse
/// onto six shapes. A position-weighted sum decorrelates them.
///
/// Neither mix uses `hashValue`. Swift seeds string hashing per process, so a
/// `hashValue`-driven gem would be a different shape on every launch.
public struct GemShape: Sendable, Equatable, Hashable {
    /// How the inside of the stone is cut. Four families, so two gems that happen to
    /// share a side count still do not share a drawing.
    public enum Facet: Int, Sendable, CaseIterable, Hashable {
        /// Crown lines fanning from the apex to every other vertex.
        case crown = 0
        /// Spokes from the centre to every vertex.
        case brilliant = 1
        /// A concentric inner polygon, its vertices tied to the outer ones.
        case step = 2
        /// A flat inner table, rotated half a step so its edges face the outer vertices.
        case table = 3
    }

    /// 5 through 10.
    public let sides: Int
    public let facet: Facet
    /// Radians, on a sixteenth-turn grid.
    public let rotation: Double

    public init(sides: Int, facet: Facet, rotation: Double) {
        self.sides = sides
        self.facet = facet
        self.rotation = rotation
    }

    public static func of(_ id: String) -> GemShape {
        var plain = 0
        var weighted = 0
        for (index, scalar) in id.unicodeScalars.enumerated() {
            plain &+= Int(scalar.value)
            weighted &+= Int(scalar.value) &* (index + 1)
        }
        return GemShape(
            sides: 5 + plain % 6,
            facet: Facet(rawValue: weighted % 4) ?? .crown,
            rotation: Double((plain &* 7 &+ weighted) % 16) / 16 * .pi
        )
    }

    /// Side count and facet family together — the part a person actually sees from across
    /// a shelf. Rotation is deliberately excluded: on a near-regular polygon it is close
    /// to invisible, and counting it is how the previous test reported eight distinct
    /// shapes while only four were on screen.
    public var visibleIdentity: String { "\(sides)/\(facet.rawValue)" }
}
