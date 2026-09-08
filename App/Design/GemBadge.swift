import SwiftUI
import MushKit

/// A gem, drawn rather than shipped.
///
/// No image assets and no emoji. The geometry comes from `GemShape` in `MushKit`, where
/// it can be — and is — tested: `gemShapesAreAllDistinct` asserts that the twelve ids in
/// the catalogue produce twelve different drawings. This view is only the rendering.
///
/// A locked gem is drawn with its own outline dashed, not as a generic placeholder, so
/// the shelf shows you the shape you are going to earn.
struct GemBadge: View {
    let gem: Gem
    let isUnlocked: Bool
    /// Unlocked gems take the creature's current colour, so the shelf reads as part of
    /// the same object rather than a separate reward currency (docs/08-DECISIONS.md D14).
    let tint: Color

    private var shape: GemShape { .of(gem.id) }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44
            let outer = vertices(center: center, radius: radius, turn: 0)

            let outline = polygon(outer)

            guard isUnlocked else {
                context.stroke(
                    outline, with: .color(Token.Color.line),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                return
            }

            context.fill(outline, with: .color(tint.opacity(0.22)))
            context.stroke(outline, with: .color(tint), lineWidth: 1.5)
            drawFacets(&context, center: center, radius: radius, outer: outer)
        }
        .accessibilityLabel(
            isUnlocked ? "\(gem.title), earned" : "\(gem.title), locked. \(gem.requirement)"
        )
    }

    // MARK: Geometry

    /// `turn` is in whole steps: 0.5 rotates by half a side, which is what makes an inner
    /// polygon present an edge to the outer polygon's vertex rather than lining up with it.
    private func vertices(center: CGPoint, radius: CGFloat, turn: Double) -> [CGPoint] {
        (0..<shape.sides).map { index in
            let angle = shape.rotation - .pi / 2
                + (Double(index) + turn) / Double(shape.sides) * 2 * .pi
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// The four cuts. This is the difference between a shelf of twelve rewards and a
    /// shelf of one reward printed twelve times.
    private func drawFacets(
        _ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, outer: [CGPoint]
    ) {
        let hairline = StrokeStyle(lineWidth: 0.75)

        switch shape.facet {
        case .crown:
            var facets = Path()
            for vertex in outer.dropFirst().dropLast() {
                facets.move(to: outer[0])
                facets.addLine(to: vertex)
            }
            context.stroke(facets, with: .color(tint.opacity(0.55)), style: hairline)

            var table = Path()
            table.move(to: outer[1])
            table.addLine(to: outer[outer.count - 1])
            context.stroke(table, with: .color(Token.Color.specular.opacity(0.5)), style: hairline)

        case .brilliant:
            var spokes = Path()
            for vertex in outer {
                spokes.move(to: center)
                spokes.addLine(to: vertex)
            }
            context.stroke(spokes, with: .color(tint.opacity(0.5)), style: hairline)

            let culet = polygon(vertices(center: center, radius: radius * 0.30, turn: 0.5))
            context.fill(culet, with: .color(tint.opacity(0.35)))
            context.stroke(culet, with: .color(Token.Color.specular.opacity(0.45)), style: hairline)

        case .step:
            let inner = vertices(center: center, radius: radius * 0.58, turn: 0)
            context.stroke(polygon(inner), with: .color(tint.opacity(0.7)), style: hairline)

            var risers = Path()
            for (index, vertex) in outer.enumerated() {
                risers.move(to: vertex)
                risers.addLine(to: inner[index])
            }
            context.stroke(risers, with: .color(tint.opacity(0.40)), style: hairline)

        case .table:
            let inner = vertices(center: center, radius: radius * 0.62, turn: 0.5)
            context.fill(polygon(inner), with: .color(tint.opacity(0.18)))
            context.stroke(
                polygon(inner), with: .color(Token.Color.specular.opacity(0.45)), style: hairline
            )

            // One bevel line per corner, from the outer vertex to the table edge it faces.
            var bevels = Path()
            for (index, vertex) in outer.enumerated() {
                bevels.move(to: vertex)
                bevels.addLine(to: inner[index])
            }
            context.stroke(bevels, with: .color(tint.opacity(0.45)), style: hairline)
        }
    }
}

/// The shelf: every gem in the catalogue, earned or not.
///
/// Nothing is hidden. Opal's gems reveal their condition only once you have them, which
/// turns a goal into a surprise — fine for a game, wrong for an app whose whole promise
/// is that you can see why the number moved.
struct GemShelf: View {
    let unlocked: Set<String>
    let tint: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var locked: [Gem] { GemCatalog.all.filter { !unlocked.contains($0.id) } }

    var body: some View {
        VStack(spacing: 16) {
            InstrumentLabel(
                title: "Gems",
                value: "\(unlocked.count)/\(GemCatalog.all.count)"
            )

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(GemCatalog.all) { gem in
                    VStack(spacing: 6) {
                        GemBadge(
                            gem: gem,
                            isUnlocked: unlocked.contains(gem.id),
                            tint: tint
                        )
                        .frame(height: 46)

                        Text(gem.title)
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundStyle(
                                unlocked.contains(gem.id) ? Token.Color.ink : Token.Color.inkDim
                            )
                    }
                }
            }

            if !locked.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("STILL TO EARN")
                        .font(.mushLabel())
                        .tracking(0.8)
                        .foregroundStyle(Token.Color.inkDim)

                    ForEach(locked) { gem in
                        HStack(alignment: .top, spacing: 8) {
                            Text(gem.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Token.Color.inkDim)
                                .frame(width: 96, alignment: .leading)
                            Text(gem.requirement)
                                .font(.system(size: 12))
                                .foregroundStyle(Token.Color.inkDim)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
    }
}
