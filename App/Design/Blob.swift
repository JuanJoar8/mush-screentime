import SwiftUI
import MushKit

/// The character: an anthropomorphic brain with gloves and shoes.
///
/// No image assets. Every curve is generated from `BrainStage`, so the creature cannot
/// drift out of sync with the number beside it — change the stage and the whole drawing
/// follows: colour, posture, brow angle, gloss, gaze.
///
/// **What makes it read as rubber rather than a flat shape.** Each gyrus is stroked three
/// times: a blurred dark groove offset *down*, the fold itself, and a thin bright crest
/// offset *up*. That trio is the whole trick. Drop the highlight and it collapses back
/// into a pink blob immediately.
///
/// **The brows do the acting.** Eyes and mouth help, but tilt and lift on two short
/// strokes carry almost all of the expression — which is why they are the parameters that
/// move most between stages.
///
/// Note the progression is not a dimmer switch. `buzzed` sits in the middle and is the
/// *most agitated* state — small pupils, wide eyes, a fine tremor — because that is what
/// an overstimulated afternoon actually feels like.
struct CreatureParameters: Equatable {
    /// Brow rotation. Negative raises the outer end (alert); positive raises the inner
    /// end, which is the universal shape of worry.
    var browTilt: CGFloat
    /// How far the brows sit above the eyes.
    var browLift: CGFloat
    /// Eyelid coverage, 0...1.
    var lid: CGFloat
    /// Eye opening, where 1 is neutral. `buzzed` goes above 1.
    var open: CGFloat
    /// Downward slump.
    var sag: CGFloat
    /// It widens as it loses structure.
    var spread: CGFloat
    /// Specular strength, and the crest/groove contrast with it. A dulled brain does not
    /// merely darken — it stops reflecting.
    var gloss: CGFloat
    /// Pupil size as a fraction of the iris. Small reads as startled.
    var pupil: CGFloat
    /// Mouth curvature. Positive smiles.
    var mouth: CGFloat
    /// Arm droop, 0 held up to 1 hanging.
    var arms: CGFloat
    /// High-frequency tremor. Only `buzzed` has one.
    var jitter: CGFloat
    /// Seconds between blinks. A duller creature blinks more slowly.
    var blinkInterval: Double

    static func forStage(_ stage: BrainStage) -> CreatureParameters {
        switch stage {
        case .crisp:
            .init(browTilt: -0.14, browLift: 0.10, lid: 0.00, open: 1.00, sag: 0.00,
                  spread: 0.00, gloss: 1.00, pupil: 0.52, mouth: 0.52, arms: 0.22,
                  jitter: 0.000, blinkInterval: 3.2)
        case .foggy:
            .init(browTilt: 0.10, browLift: 0.06, lid: 0.20, open: 0.92, sag: 0.05,
                  spread: 0.04, gloss: 0.62, pupil: 0.50, mouth: 0.06, arms: 0.40,
                  jitter: 0.000, blinkInterval: 4.6)
        case .buzzed:
            .init(browTilt: -0.34, browLift: 0.13, lid: 0.00, open: 1.16, sag: 0.02,
                  spread: 0.03, gloss: 0.78, pupil: 0.30, mouth: -0.16, arms: 0.18,
                  jitter: 0.050, blinkInterval: 1.1)
        case .melting:
            .init(browTilt: 0.30, browLift: 0.04, lid: 0.42, open: 0.82, sag: 0.13,
                  spread: 0.10, gloss: 0.30, pupil: 0.46, mouth: -0.42, arms: 0.65,
                  jitter: 0.000, blinkInterval: 6.4)
        case .mush:
            .init(browTilt: 0.42, browLift: 0.02, lid: 0.62, open: 0.72, sag: 0.22,
                  spread: 0.16, gloss: 0.16, pupil: 0.40, mouth: -0.58, arms: 0.85,
                  jitter: 0.000, blinkInterval: 8.8)
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

/// The palette for one stage, derived from its single token.
///
/// Built with `Color.mix(with:by:)` rather than stored hexes: the token contract says a
/// colour literal in a view is a bug, and mixing keeps every shade tied to the one value
/// in `brand.json`.
private struct Palette {
    let base: Color
    let light: Color
    let lighter: Color
    let dark: Color
    let darker: Color
    let shell: Color
    let brow: Color

    init(stage: BrainStage, gloss: CGFloat) {
        let tint = stage.tint
        let white = Token.Color.specular
        base = tint
        light = tint.mix(with: white, by: Double(0.34 * gloss + 0.10))
        lighter = tint.mix(with: white, by: Double(0.62 * gloss + 0.12))
        dark = tint.mix(with: Token.Color.groundDeep, by: 0.24)
        darker = tint.mix(with: Token.Color.groundDeep, by: 0.46)
        // Gloves and shoes: white, warmed very slightly by the body so they belong to the
        // same creature rather than being pasted on.
        shell = white.mix(with: tint, by: 0.06)
        brow = tint.mix(with: Token.Color.groundDeep, by: 0.66)
    }
}

struct BlobView: View {
    let stage: BrainStage
    /// Draw one frame and stop. Widgets and Live Activities are static snapshots, so
    /// `TimelineView(.animation)` there would burn a render pass to produce identical
    /// pixels.
    var isStatic: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var p: CreatureParameters { .forStage(stage) }

    var body: some View {
        Group {
            if isStatic {
                Canvas { context, size in
                    draw(context: context, size: size, time: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    Canvas { context, size in
                        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        draw(context: context, size: size, time: time)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: Token.Duration.slow), value: stage)
        .accessibilityHidden(true)
    }

    // MARK: Composition

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        var context = context
        let palette = Palette(stage: stage, gloss: p.gloss)

        let cx = size.width / 2
        let radius = min(size.width, size.height) * 0.30
        // Idle breathing: slow, small, and the only thing that moves at rest.
        let breathe = CGFloat(sin(time * 0.9)) * radius * 0.014
        let tremor = p.jitter > 0 ? CGFloat(sin(time * 17)) * radius * p.jitter * 0.5 : 0
        let cy = size.height * 0.40 + radius * p.sag + breathe

        let bodyW = radius * (1.30 + p.spread)
        let bodyH = radius * (1.06 - p.spread * 0.30)
        let center = CGPoint(x: cx + tremor, y: cy)

        drawShadow(&context, center: center, size: size, bodyW: bodyW, radius: radius)
        drawLegs(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius, palette: palette)
        drawArms(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time)
        drawBody(&context, center: center, bodyW: bodyW, bodyH: bodyH, palette: palette)
        drawFace(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time)
    }

    // MARK: Ground

    private func drawShadow(
        _ context: inout GraphicsContext, center: CGPoint, size: CGSize,
        bodyW: CGFloat, radius: CGFloat
    ) {
        let rect = CGRect(
            x: center.x - bodyW * 0.62, y: size.height * 0.86 - radius * 0.11,
            width: bodyW * 1.24, height: radius * 0.22
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.09))
            layer.opacity = 0.34 - p.sag * 0.4
            layer.fill(Path(ellipseIn: rect), with: .color(Token.Color.groundDeep))
        }
    }

    // MARK: Limbs

    /// A rounded limb: one thick stroke, then a thin light stroke along its upper edge.
    /// Two strokes is the cheapest thing that stops a line reading as a line.
    private func limb(
        _ context: inout GraphicsContext, points: [CGPoint], width: CGFloat,
        colour: Color, highlight: Color
    ) {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }

        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(colour), style: style)

        context.drawLayer { layer in
            layer.translateBy(x: -width * 0.12, y: -width * 0.16)
            layer.stroke(
                path, with: .color(highlight),
                style: StrokeStyle(lineWidth: width * 0.30, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawLegs(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette
    ) {
        let hipY = center.y + bodyH * 0.80
        let footY = hipY + radius * (0.62 - p.sag * 0.9)
        let spread = bodyW * (0.30 + p.spread * 1.1)

        for side in [-1.0, 1.0] as [CGFloat] {
            let x0 = center.x + side * bodyW * 0.20
            let x1 = center.x + side * spread
            limb(&context, points: [CGPoint(x: x0, y: hipY), CGPoint(x: x1, y: footY)],
                 width: radius * 0.115, colour: palette.base,
                 highlight: palette.light.opacity(0.75))

            // Shoe: a squat wedge plus a darker sole, tilted outward.
            context.drawLayer { layer in
                layer.translateBy(x: x1, y: footY)
                layer.rotate(by: .radians(Double(side) * 0.12))
                let upper = CGRect(
                    x: side * radius * 0.07 - radius * 0.20, y: radius * 0.045 - radius * 0.115,
                    width: radius * 0.40, height: radius * 0.23
                )
                layer.fill(Path(ellipseIn: upper), with: .color(palette.shell))
                let sole = CGRect(
                    x: side * radius * 0.07 - radius * 0.20, y: radius * 0.10 - radius * 0.045,
                    width: radius * 0.40, height: radius * 0.09
                )
                layer.fill(
                    Path(ellipseIn: sole),
                    with: .color(palette.shell.mix(with: Token.Color.groundDeep, by: 0.12))
                )
            }
        }
    }

    private func drawArms(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette, time: TimeInterval
    ) {
        let drop = p.arms
        let sway = CGFloat(sin(time * 0.7)) * 0.03

        for side in [-1.0, 1.0] as [CGFloat] {
            let shoulder = CGPoint(x: center.x + side * bodyW * 0.80, y: center.y + bodyH * 0.28)
            let elbow = CGPoint(
                x: center.x + side * bodyW * (1.06 - drop * 0.06),
                y: shoulder.y + radius * (0.06 + drop * 0.26)
            )
            let wrist = CGPoint(
                x: center.x + side * bodyW * (1.02 + drop * 0.10),
                y: shoulder.y + radius * (0.30 + drop * 0.52 + sway)
            )

            limb(&context, points: [shoulder, elbow, wrist], width: radius * 0.105,
                 colour: palette.base, highlight: palette.light.opacity(0.7))

            // Glove: a ball and a thumb. Two circles is all it takes to stop reading as
            // a dot on the end of a stick.
            let palm = CGRect(
                x: wrist.x - radius * 0.135, y: wrist.y - radius * 0.135,
                width: radius * 0.27, height: radius * 0.27
            )
            context.fill(Path(ellipseIn: palm), with: .color(palette.shell))

            let thumb = CGRect(
                x: wrist.x - side * radius * 0.10 - radius * 0.058,
                y: wrist.y - radius * 0.06 - radius * 0.058,
                width: radius * 0.116, height: radius * 0.116
            )
            context.fill(Path(ellipseIn: thumb), with: .color(palette.shell))
        }
    }

    // MARK: Body

    /// Two hemispheres under one skin: an ellipse with a shallow dip at the crown, so the
    /// silhouette says "brain" before a single fold is drawn.
    private func bodyPath(center c: CGPoint, bodyW w: CGFloat, bodyH h: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: c.x - w, y: c.y))
        path.addCurve(
            to: CGPoint(x: c.x - w * 0.16, y: c.y - h * 1.00),
            control1: CGPoint(x: c.x - w, y: c.y - h * 1.02),
            control2: CGPoint(x: c.x - w * 0.52, y: c.y - h * 1.16)
        )
        path.addCurve(
            to: CGPoint(x: c.x + w * 0.16, y: c.y - h * 1.00),
            control1: CGPoint(x: c.x - w * 0.06, y: c.y - h * 0.94),
            control2: CGPoint(x: c.x + w * 0.06, y: c.y - h * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: c.x + w, y: c.y),
            control1: CGPoint(x: c.x + w * 0.52, y: c.y - h * 1.16),
            control2: CGPoint(x: c.x + w, y: c.y - h * 1.02)
        )
        path.addCurve(
            to: CGPoint(x: c.x, y: c.y + h * 1.02),
            control1: CGPoint(x: c.x + w, y: c.y + h * 0.86),
            control2: CGPoint(x: c.x + w * 0.56, y: c.y + h * 1.02)
        )
        path.addCurve(
            to: CGPoint(x: c.x - w, y: c.y),
            control1: CGPoint(x: c.x - w * 0.56, y: c.y + h * 1.02),
            control2: CGPoint(x: c.x - w, y: c.y + h * 0.86)
        )
        path.closeSubpath()
        return path
    }

    private func drawBody(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, palette: Palette
    ) {
        let silhouette = bodyPath(center: center, bodyW: bodyW, bodyH: bodyH)

        context.fill(
            silhouette,
            with: .radialGradient(
                Gradient(colors: [palette.lighter, palette.base, palette.dark]),
                center: CGPoint(x: center.x - bodyW * 0.34, y: center.y - bodyH * 0.52),
                startRadius: bodyW * 0.08,
                endRadius: bodyW * 1.25
            )
        )

        context.drawLayer { layer in
            layer.clip(to: silhouette)
            drawGyri(&layer, center: center, bodyW: bodyW, bodyH: bodyH, palette: palette)

            // Rim occlusion: a thick blurred stroke *inside* the silhouette, so the volume
            // does not end at a flat edge.
            layer.drawLayer { rim in
                rim.addFilter(.blur(radius: bodyW * 0.07))
                rim.stroke(
                    silhouette, with: .color(palette.darker.opacity(0.5)),
                    style: StrokeStyle(lineWidth: bodyW * 0.20)
                )
            }

            if p.gloss > 0.05 {
                let spec = CGRect(
                    x: center.x - bodyW * 0.44 - bodyW * 0.22,
                    y: center.y - bodyH * 0.62 - bodyH * 0.14,
                    width: bodyW * 0.44, height: bodyH * 0.28
                )
                layer.drawLayer { highlight in
                    highlight.addFilter(.blur(radius: bodyW * 0.05))
                    highlight.opacity = 0.30 * p.gloss
                    highlight.fill(Path(ellipseIn: spec), with: .color(Token.Color.specular))
                }
            }
        }
    }

    /// Deterministic pseudo-random. The same fold pattern every frame and every launch —
    /// a creature whose brain rearranged itself between frames would read as noise.
    private func rnd(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 127.1 + 311.7) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    private func drawGyri(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, palette: Palette
    ) {
        let tube = bodyW * 0.20

        for side in [-1.0, 1.0] as [CGFloat] {
            for k in 0..<5 {
                let r1 = rnd(k * 3 + (side > 0 ? 41 : 7))
                let r2 = rnd(k * 5 + (side > 0 ? 73 : 19))

                let y = center.y - bodyH * (0.74 - CGFloat(k) * 0.32) + bodyH * r1 * 0.10
                var fold = Path()
                fold.move(to: CGPoint(x: center.x + side * bodyW * 0.06, y: y))
                fold.addCurve(
                    to: CGPoint(x: center.x + side * bodyW * (0.98 + r2 * 0.10),
                                y: y + bodyH * (0.02 + r1 * 0.10)),
                    control1: CGPoint(x: center.x + side * bodyW * (0.42 + r1 * 0.18),
                                      y: y - bodyH * (0.16 + r1 * 0.12)),
                    control2: CGPoint(x: center.x + side * bodyW * (0.58 + r1 * 0.18),
                                      y: y + bodyH * (0.14 + r2 * 0.10))
                )

                let round = StrokeStyle(lineWidth: tube, lineCap: .round, lineJoin: .round)

                // Groove shadow, offset down.
                context.drawLayer { layer in
                    layer.translateBy(x: 0, y: tube * 0.30)
                    layer.addFilter(.blur(radius: tube * 0.16))
                    layer.stroke(fold, with: .color(palette.darker.opacity(0.55)), style: round)
                }

                // The fold itself.
                context.stroke(fold, with: .color(palette.base.opacity(0.92)), style: round)

                // Crest highlight, offset up. This is the stroke that makes it rubber.
                context.drawLayer { layer in
                    layer.translateBy(x: 0, y: -tube * 0.26)
                    layer.addFilter(.blur(radius: tube * 0.10))
                    layer.stroke(
                        fold,
                        with: .color(palette.lighter.opacity(0.30 + 0.42 * p.gloss)),
                        style: StrokeStyle(lineWidth: tube * 0.42, lineCap: .round)
                    )
                }
            }
        }

        // Longitudinal fissure: deeper than any groove, and what splits the two halves.
        var fissure = Path()
        fissure.move(to: CGPoint(x: center.x, y: center.y - bodyH * 1.02))
        fissure.addCurve(
            to: CGPoint(x: center.x, y: center.y + bodyH * 0.30),
            control1: CGPoint(x: center.x + bodyW * 0.03, y: center.y - bodyH * 0.55),
            control2: CGPoint(x: center.x - bodyW * 0.03, y: center.y - bodyH * 0.10)
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: bodyW * 0.020))
            layer.stroke(
                fissure, with: .color(palette.darker.opacity(0.62)),
                style: StrokeStyle(lineWidth: bodyW * 0.045, lineCap: .round)
            )
        }
    }

    // MARK: Face

    private func drawFace(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette, time: TimeInterval
    ) {
        let eyeY = center.y + bodyH * 0.06
        let eyeX = bodyW * 0.36
        let rx = radius * 0.185
        let ry = rx * 1.06 * p.open

        // Blink. Cheap, and most of what makes something read as alive.
        let cycle = time.truncatingRemainder(dividingBy: p.blinkInterval)
        let blink: CGFloat = cycle < 0.12 ? 0.08 : 1

        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX

            let sclera = CGRect(x: ex - rx, y: eyeY - ry * blink,
                                width: rx * 2, height: ry * blink * 2)
            context.fill(Path(ellipseIn: sclera), with: .color(Token.Color.specular))

            if blink > 0.5 {
                // Buzzed cannot hold a gaze.
                let gaze = p.jitter > 0 ? CGFloat(sin(time * 5.3 + Double(side))) * rx * 0.16 : 0
                let irisR = rx * (0.60 + p.pupil * 0.10)
                let ix = ex + gaze
                let iy = eyeY + ry * 0.06

                // A limbal ring, so the iris is not a flat dot.
                let iris = CGRect(x: ix - irisR, y: iy - irisR, width: irisR * 2, height: irisR * 2)
                context.fill(
                    Path(ellipseIn: iris),
                    with: .radialGradient(
                        Gradient(colors: [Token.Color.eyeIris, Token.Color.eyeIrisDeep]),
                        center: CGPoint(x: ix, y: iy - irisR * 0.3),
                        startRadius: irisR * 0.15, endRadius: irisR
                    )
                )

                let pupilR = irisR * p.pupil
                context.fill(
                    Path(ellipseIn: CGRect(x: ix - pupilR, y: iy - pupilR,
                                           width: pupilR * 2, height: pupilR * 2)),
                    with: .color(Token.Color.eyePupil)
                )

                let glintR = irisR * 0.26
                context.fill(
                    Path(ellipseIn: CGRect(x: ix - irisR * 0.34 - glintR,
                                           y: iy - irisR * 0.40 - glintR,
                                           width: glintR * 2, height: glintR * 2)),
                    with: .color(Token.Color.specular.opacity(0.92))
                )

                // Heavy lid, in the body colour, so it reads as the brain closing over
                // the eye rather than a grey bar laid on top.
                if p.lid > 0.01 {
                    context.drawLayer { layer in
                        layer.clip(to: Path(ellipseIn: sclera.insetBy(dx: -1, dy: -1)))
                        let depth = (ry * 2 + 4) * p.lid * 0.62
                        layer.fill(
                            Path(CGRect(x: sclera.minX - 2, y: sclera.minY - 2,
                                        width: sclera.width + 4, height: depth)),
                            with: .color(palette.base)
                        )
                    }
                }
            }

            // Brow. Inner end lifts for worry, drops for alert.
            context.drawLayer { layer in
                layer.translateBy(x: ex, y: eyeY - ry - radius * (0.10 + p.browLift))
                layer.rotate(by: .radians(Double(side * p.browTilt)))
                let bw = rx * 1.22
                var brow = Path()
                brow.move(to: CGPoint(x: -bw * 0.5, y: radius * 0.02))
                brow.addQuadCurve(
                    to: CGPoint(x: bw * 0.5, y: radius * 0.012),
                    control: CGPoint(x: 0, y: -radius * 0.045)
                )
                layer.stroke(
                    brow, with: .color(palette.brow),
                    style: StrokeStyle(lineWidth: radius * 0.062, lineCap: .round)
                )
            }
        }

        // Mouth: one curve, and the control point carries the whole mood.
        let my = eyeY + radius * 0.46
        let mw = radius * 0.24
        var mouth = Path()
        mouth.move(to: CGPoint(x: center.x - mw, y: my))
        mouth.addQuadCurve(
            to: CGPoint(x: center.x + mw, y: my),
            control: CGPoint(x: center.x, y: my + radius * 0.30 * p.mouth)
        )
        context.stroke(
            mouth, with: .color(palette.darker.opacity(0.85)),
            style: StrokeStyle(lineWidth: radius * 0.038, lineCap: .round)
        )
    }
}

#Preview("Every stage") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
                HStack {
                    BlobView(stage: stage)
                        .frame(width: 150, height: 150)
                    Text(stage.title)
                        .font(.mushDisplay(24))
                        .foregroundStyle(stage.tint)
                    Spacer()
                }
            }
        }
        .padding()
    }
    .background(Token.Color.ground)
}
