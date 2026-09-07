import SwiftUI
import MushKit

/// A gem, drawn rather than shipped.
///
/// No image assets and no emoji: the shape is a polygon whose side count and rotation are
/// derived from the gem's id, so every one in the catalogue is visibly distinct and stays
/// that way for the life of the app.
///
/// The derivation uses the id's unicode scalars, **not** `hashValue`. Swift's string
/// hashing is seeded per process, so a `hashValue`-driven shape would be a different gem
/// on every launch.
struct GemBadge: View {
    let gem: Gem
    let isUnlocked: Bool
    /// Unlocked gems take the creature's current colour, so the shelf reads as part of
    /// the same object rather than a separate reward currency.
    let tint: Color

    private var seed: Int {
        gem.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    }

    private var sides: Int { 5 + seed % 4 }
    private var rotation: Double { Double(seed % 12) / 12 * .pi }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44

            var outline = Path()
            var vertices: [CGPoint] = []
            for index in 0..<sides {
                let angle = rotation - .pi / 2 + Double(index) / Double(sides) * 2 * .pi
                let point = CGPoint(
                    x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle))
                )
                vertices.append(point)
                if index == 0 { outline.move(to: point) } else { outline.addLine(to: point) }
            }
            outline.closeSubpath()

            if isUnlocked {
                context.fill(outline, with: .color(tint.opacity(0.22)))
                context.stroke(outline, with: .color(tint), lineWidth: 1.5)

                // Facets: the crown lines from the top vertex. This is the whole reason a
                // flat polygon reads as a cut stone rather than a badge.
                var facets = Path()
                for vertex in vertices.dropFirst().dropLast() {
                    facets.move(to: vertices[0])
                    facets.addLine(to: vertex)
                }
                context.stroke(facets, with: .color(tint.opacity(0.55)), lineWidth: 0.75)

                var table = Path()
                table.move(to: vertices[1])
                table.addLine(to: vertices[vertices.count - 1])
                context.stroke(table, with: .color(Token.Color.specular.opacity(0.5)), lineWidth: 0.75)
            } else {
                context.stroke(
                    outline,
                    with: .color(Token.Color.line),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            }
        }
        .accessibilityLabel(
            isUnlocked ? "\(gem.title), earned" : "\(gem.title), locked. \(gem.requirement)"
        )
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
