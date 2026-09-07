import SwiftUI
import MushKit

/// The character.
///
/// No image assets: the silhouette is a closed path whose radius is modulated by
/// phase-offset sine waves, and every parameter is derived from `BrainStage` rather than
/// hand-picked per state. That is the point — the creature is a rendering of the model,
/// so it cannot drift out of sync with the number next to it.
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
    /// Vertical compression - it spreads as it loses structure.
    var squish: CGFloat
    /// High-frequency tremor, used only by `buzzed`.
    var jitter: CGFloat
    /// Seconds between blinks. Lower is more alert.
    var blinkInterval: Double

    static func forStage(_ stage: BrainStage) -> BlobParameters {
        switch stage {
        case .crisp:
            .init(amplitude: 0.035, frequency: 0.55, sag: 0.00, squish: 0.00, jitter: 0.000, blinkInterval: 3.2)
        case .foggy:
            .init(amplitude: 0.055, frequency: 0.40, sag: 0.04, squish: 0.03, jitter: 0.000, blinkInterval: 4.6)
        case .buzzed:
            .init(amplitude: 0.070, frequency: 1.65, sag: 0.02, squish: 0.00, jitter: 0.030, blinkInterval: 1.1)
        case .melting:
            .init(amplitude: 0.090, frequency: 0.25, sag: 0.16, squish: 0.12, jitter: 0.000, blinkInterval: 6.5)
        case .mush:
            .init(amplitude: 0.120, frequency: 0.15, sag: 0.30, squish: 0.26, jitter: 0.000, blinkInterval: 9.0)
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
    /// 0...1 within the stage. Lets the creature deform continuously rather than
    /// snapping between five poses.
    var progress: Double = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var parameters: BlobParameters { .forStage(stage) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate
                draw(context: context, size: size, time: time)
            }
        }
        .animation(.easeInOut(duration: Token.Duration.slow), value: stage)
        .accessibilityHidden(true)
    }

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let p = parameters
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let base = min(size.width, size.height) * 0.36

        var path = Path()
        let steps = 120

        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let angle = t * 2 * .pi

            // Three phase-offset harmonics give an organic, non-repeating outline.
            let wave =
                sin(angle * 3 + time * p.frequency * 1.0) * 0.55
                + sin(angle * 5 - time * p.frequency * 0.7) * 0.30
                + sin(angle * 2 + time * p.frequency * 1.4) * 0.15

            // Tremor: fast, small, and only present when the creature is buzzed.
            let tremor = p.jitter > 0
                ? sin(angle * 11 + time * 9.0) * Double(p.jitter)
                : 0

            var radius = base * (1 + p.amplitude * CGFloat(wave) + CGFloat(tremor))

            // Sag: the lower half loses structure first, so the droop is weighted by
            // how far below the equator the point sits.
            let below = max(0, sin(angle - .pi / 2) * -1)
            radius += base * p.sag * CGFloat(below) * 0.5

            var x = center.x + radius * CGFloat(cos(angle))
            var y = center.y + radius * CGFloat(sin(angle))

            // Squish flattens it vertically and lets it spread sideways.
            y = center.y + (y - center.y) * (1 - p.squish)
            x = center.x + (x - center.x) * (1 + p.squish * 0.45)
            // Everything settles downward as it deteriorates.
            y += base * p.sag * 0.55

            if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()

        context.fill(path, with: .color(stage.tint))

        drawFace(context: context, center: center, base: base, time: time, p: p)
    }

    private func drawFace(
        context: GraphicsContext,
        center: CGPoint,
        base: CGFloat,
        time: TimeInterval,
        p: BlobParameters
    ) {
        let eyeOffset = base * 0.34
        let eyeY = center.y - base * 0.08 + base * p.sag * 0.55
        let eyeRadius = base * 0.085

        // Blink: eyes close for a slice of each interval. Cheap and it reads as alive.
        let cycle = time.truncatingRemainder(dividingBy: p.blinkInterval)
        let isBlinking = cycle < 0.12
        let openness: CGFloat = isBlinking ? 0.12 : 1.0

        // Buzzed eyes drift; the creature cannot hold a gaze.
        let drift = p.jitter > 0 ? CGFloat(sin(time * 6.0)) * base * 0.03 : 0

        for side in [-1.0, 1.0] as [CGFloat] {
            let rect = CGRect(
                x: center.x + side * eyeOffset - eyeRadius + drift,
                y: eyeY - eyeRadius * openness,
                width: eyeRadius * 2,
                height: eyeRadius * 2 * openness
            )
            context.fill(Path(ellipseIn: rect), with: .color(Token.Color.inkOnViewport))
        }
    }
}

#Preview("Every stage") {
    VStack(spacing: 0) {
        ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
            HStack {
                BlobView(stage: stage)
                    .frame(width: 110, height: 110)
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
