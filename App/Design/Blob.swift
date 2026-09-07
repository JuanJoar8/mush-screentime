import SwiftUI
import MushKit

/// The character.
///
/// No image assets: the silhouette is a closed path whose radius is modulated by
/// phase-offset sine waves, and every parameter is derived from `BrainStage` rather than
/// hand-picked per state. That is the point — the creature is a rendering of the model,
/// so it cannot drift out of sync with the number beside it.
///
/// Two things learned from the first pass, both visible in a screenshot:
/// **use low harmonics.** Modulating on harmonics 3 and 5 produces a symmetric rosette
/// that reads as a cog or a flower. Harmonics 1–3 with unequal weights and irrational
/// phase offsets produce an asymmetric mass that reads as something soft.
/// **Do not put anything on its face.** The number lives below it now.
///
/// Note the progression is not a dimmer switch. `buzzed` sits in the middle and is the
/// *fastest, most agitated* state, because that is what an overstimulated afternoon
/// actually feels like.
struct BlobParameters: Equatable {
    /// Deviation of the outline from a circle, as a fraction of the radius.
    var amplitude: CGFloat
    /// Wobble speed.
    var frequency: Double
    /// Downward droop. 0 holds its shape; high values sag like warm gelatin.
    var sag: CGFloat
    /// Vertical compression — it spreads as it loses structure.
    var squish: CGFloat
    /// High-frequency tremor, used only by `buzzed`.
    var jitter: CGFloat
    /// Seconds between blinks. Lower is more alert.
    var blinkInterval: Double
    /// Mouth curvature. Positive smiles, negative frowns.
    var mouth: CGFloat
    /// How far apart the eyes sit, as a fraction of radius. They drift apart as it melts.
    var eyeSpread: CGFloat

    static func forStage(_ stage: BrainStage) -> BlobParameters {
        switch stage {
        case .crisp:
            .init(amplitude: 0.10, frequency: 0.50, sag: 0.00, squish: 0.00,
                  jitter: 0.000, blinkInterval: 3.4, mouth: 0.55, eyeSpread: 0.30)
        case .foggy:
            .init(amplitude: 0.14, frequency: 0.34, sag: 0.05, squish: 0.04,
                  jitter: 0.000, blinkInterval: 5.0, mouth: 0.10, eyeSpread: 0.31)
        case .buzzed:
            .init(amplitude: 0.17, frequency: 1.70, sag: 0.03, squish: 0.02,
                  jitter: 0.022, blinkInterval: 1.0, mouth: -0.15, eyeSpread: 0.33)
        case .melting:
            .init(amplitude: 0.22, frequency: 0.22, sag: 0.20, squish: 0.14,
                  jitter: 0.000, blinkInterval: 6.8, mouth: -0.45, eyeSpread: 0.36)
        case .mush:
            .init(amplitude: 0.27, frequency: 0.13, sag: 0.34, squish: 0.28,
                  jitter: 0.000, blinkInterval: 9.5, mouth: -0.65, eyeSpread: 0.40)
        }
    }
}

extension BrainStage {
    var tint: Color {
        switch self {
        case .crisp: Token.Color.stageCrisp
        case .foggy: Token.Color.stageFoggy
        case .buzzed: Token.Color.stageBuzzed
        case .melting: Token.Color.stageMelting
        case .mush: Token.Color.stageMush
        }
    }
}

struct BlobView: View {
    let stage: BrainStage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var parameters: BlobParameters { .forStage(stage) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                draw(context: context, size: size, time: time)
            }
        }
        .animation(.easeInOut(duration: Token.Duration.slow), value: stage)
        .accessibilityHidden(true)
    }

    // MARK: Silhouette

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let p = parameters
        let center = CGPoint(x: size.width / 2, y: size.height * 0.47)
        let base = min(size.width, size.height) * 0.40

        var path = Path()
        let steps = 160

        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let angle = t * 2 * .pi

            // Low harmonics with unequal weights and mutually irrational phase speeds.
            // Harmonic 1 is what makes it lopsided rather than radially symmetric.
            let wave =
                sin(angle * 1 + time * p.frequency * 0.73) * 0.50
                + sin(angle * 2 - time * p.frequency * 0.41) * 0.32
                + sin(angle * 3 + time * p.frequency * 0.97) * 0.18

            let tremor = p.jitter > 0
                ? sin(angle * 7 + time * 11.0) * Double(p.jitter)
                : 0

            var radius = base * (1 + p.amplitude * CGFloat(wave) + CGFloat(tremor))

            // Sag: the lower half loses structure first, so the droop is weighted by how
            // far below the equator the point sits.
            let below = max(0, -sin(angle))
            radius += base * p.sag * CGFloat(below) * 0.55

            var x = center.x + radius * CGFloat(cos(angle))
            var y = center.y + radius * CGFloat(sin(angle))

            // A mass sits wider than it is tall, and spreads further as it deteriorates.
            y = center.y + (y - center.y) * (1 - p.squish)
            x = center.x + (x - center.x) * (1.10 + p.squish * 0.5)
            y += base * p.sag * 0.45

            if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()

        context.fill(path, with: .color(stage.tint))
        drawFace(context: context, center: center, base: base, time: time, p: p)
    }

    // MARK: Face

    private func drawFace(
        context: GraphicsContext,
        center: CGPoint,
        base: CGFloat,
        time: TimeInterval,
        p: BlobParameters
    ) {
        let ink = Token.Color.inkOnViewport
        let faceY = center.y - base * 0.06 + base * p.sag * 0.45
        let eyeX = base * p.eyeSpread
        let eyeR = base * 0.075

        // Blink. Cheap, and it is most of what makes something read as alive.
        let cycle = time.truncatingRemainder(dividingBy: p.blinkInterval)
        let openness: CGFloat = cycle < 0.13 ? 0.10 : 1.0

        // Buzzed eyes drift; the creature cannot hold a gaze.
        let drift = p.jitter > 0 ? CGFloat(sin(time * 6.5)) * base * 0.035 : 0

        for side in [-1.0, 1.0] as [CGFloat] {
            let rect = CGRect(
                x: center.x + side * eyeX - eyeR + drift,
                y: faceY - eyeR * openness,
                width: eyeR * 2,
                height: eyeR * 2 * openness
            )
            context.fill(Path(ellipseIn: rect), with: .color(ink))
        }

        // Mouth: one quadratic curve whose control point carries the whole expression.
        let mouthY = faceY + base * 0.30
        let mouthWidth = base * 0.34
        var mouth = Path()
        mouth.move(to: CGPoint(x: center.x - mouthWidth, y: mouthY))
        mouth.addQuadCurve(
            to: CGPoint(x: center.x + mouthWidth, y: mouthY),
            control: CGPoint(x: center.x, y: mouthY + base * 0.30 * p.mouth)
        )
        context.stroke(
            mouth,
            with: .color(ink),
            style: StrokeStyle(lineWidth: base * 0.055, lineCap: .round)
        )
    }
}

#Preview("Every stage") {
    VStack(spacing: 0) {
        ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
            HStack {
                BlobView(stage: stage)
                    .frame(width: 120, height: 120)
                Text(stage.title)
                    .font(.mushDisplay(24))
                    .foregroundStyle(Token.Color.inkOnViewport)
                Spacer()
            }
        }
    }
    .padding()
    .background(Token.Color.viewport)
}
