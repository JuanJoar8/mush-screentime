import SwiftUI
import MushKit

/// The character: an anthropomorphic brain in round wire glasses.
///
/// No image assets. Every curve is generated from `BrainStage`, so the creature cannot
/// drift out of sync with the number beside it — change the stage and the whole drawing
/// follows: colour, posture, brow angle, gaze, how far the mouth opens.
///
/// **It is drawn flat, in one ink.** The previous version was moulded rubber: radial
/// gradients, thirty blurred layers, a specular ellipse, gloves and shoes. It was
/// technically impressive and it read as a stock 3D render. This one is a sticker —
/// solid fill, one heavy contour, thin ink lines for the folds, spindly limbs — which
/// is the genre the reference actually belongs to, and which survives being shrunk to
/// 20pt in the Dynamic Island where a blur is sub-pixel and simply wasted.
///
/// **One ink, not black.** The reference draws its outline, glasses and limbs in black
/// on white. Black on our indigo ground disappears the moment a temple arm or a
/// fingertip leaves the body, so the ink is derived from the creature's own stage tint
/// instead: dark enough to read as a drawn line on the body, light enough to stay
/// visible off it. Adapting the ink to the ground is the translation; keeping the black
/// would have been the copy.
///
/// **The glasses are the signature.** They are the one element you would describe first,
/// they carry the "thinking" reading the product needs, and they give the face a
/// structure that survives at widget size. They are drawn last, over the eyes, exactly
/// as a real pair sits.
///
/// **The brows do the acting.** Eyes and mouth help, but tilt and lift on two short
/// strokes carry almost all of the expression — which is why they are the parameters
/// that move most between stages.
///
/// Note the progression is not a dimmer switch. `buzzed` sits in the middle and is the
/// *most agitated* state — small pupils, wide eyes, a fine tremor — because that is what
/// an overstimulated afternoon actually feels like.
struct CreatureParameters: Equatable {
    /// Brow rotation. Negative raises the outer end (alert); positive raises the inner
    /// end, which is the universal shape of worry.
    var browTilt: CGFloat
    /// How far the brows sit above the glasses.
    var browLift: CGFloat
    /// Eyelid coverage, 0...1.
    var lid: CGFloat
    /// Eye opening, where 1 is neutral. `buzzed` goes above 1.
    var open: CGFloat
    /// Downward slump.
    var sag: CGFloat
    /// It widens as it loses structure.
    var spread: CGFloat
    /// Sheen strength: how present the flat white highlight strokes are, and how far the
    /// blush carries. A dulled brain does not merely darken — it stops catching light.
    var sheen: CGFloat
    /// How much iris shows around the pupil. Low is a blown pupil; high is a startled
    /// ring of colour. `buzzed` is the high one.
    var pupil: CGFloat
    /// Mouth. Above ~0.15 it opens; below, it is a single stroked curve, and negative
    /// turns it down.
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
            .init(browTilt: -0.16, browLift: 0.10, lid: 0.00, open: 1.00, sag: 0.00,
                  spread: 0.00, sheen: 1.00, pupil: 0.10, mouth: 0.85, arms: 0.16,
                  jitter: 0.000, blinkInterval: 3.2)
        case .foggy:
            .init(browTilt: 0.12, browLift: 0.06, lid: 0.18, open: 0.92, sag: 0.05,
                  spread: 0.04, sheen: 0.66, pupil: 0.16, mouth: 0.22, arms: 0.40,
                  jitter: 0.000, blinkInterval: 4.6)
        case .buzzed:
            .init(browTilt: -0.36, browLift: 0.14, lid: 0.00, open: 1.18, sag: 0.02,
                  spread: 0.03, sheen: 0.82, pupil: 0.42, mouth: -0.18, arms: 0.14,
                  jitter: 0.050, blinkInterval: 1.1)
        case .melting:
            .init(browTilt: 0.32, browLift: 0.04, lid: 0.40, open: 0.82, sag: 0.13,
                  spread: 0.10, sheen: 0.32, pupil: 0.14, mouth: -0.46, arms: 0.66,
                  jitter: 0.000, blinkInterval: 6.4)
        case .mush:
            .init(browTilt: 0.44, browLift: 0.02, lid: 0.60, open: 0.72, sag: 0.22,
                  spread: 0.16, sheen: 0.14, pupil: 0.10, mouth: -0.62, arms: 0.86,
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
///
/// Five entries, where the old one had seven. Flat drawing needs fewer shades than
/// moulded drawing does — that is most of why it reads as cleaner.
private struct Palette {
    /// Solid body fill.
    let base: Color
    /// The one ink: contour, folds, glasses, limbs, mouth, brows.
    let ink: Color
    /// Cheeks. Warmed toward `bad`, which is the only warm red in the system.
    let blush: Color
    /// Flat highlight strokes. The only white in the drawing besides the sclera.
    let shine: Color
    /// Tongue.
    let tongue: Color

    init(stage: BrainStage) {
        let tint = stage.tint
        base = tint

        // Warmed *before* it is darkened. Mixing a tint straight toward the deep ground
        // desaturates it on the way: the amber stage came out olive and the grey stages
        // came out dead. A touch of `bad` first keeps the line a deeper version of the
        // body colour rather than a grey one.
        ink = tint.mix(with: Token.Color.bad, by: 0.20)
            .mix(with: Token.Color.groundDeep, by: 0.46)
        blush = tint.mix(with: Token.Color.bad, by: 0.52)
        shine = Token.Color.specular
        tongue = Token.Color.bad.mix(with: Token.Color.groundDeep, by: 0.10)
    }
}

/// The drawing's extents, in units of `radius`, derived from the constants the drawing
/// actually uses rather than measured off a screenshot.
///
/// Everything here is a worst case across all five stages: `spread` widens the body by up
/// to 16% and `sag` drops it by up to 22%, so the fit has to hold for the widest and the
/// lowest, not for the one that happens to be on screen.
private enum Reach {
    static let maxSpread: CGFloat = 0.16
    static let maxSag: CGFloat = 0.22
    /// Silhouette harmonics, at their peak: 1 + 0.056 + 0.028.
    static let lump: CGFloat = 1.092
    /// Half the contour stroke.
    static let contour: CGFloat = 0.036

    static let armSpan: CGFloat = 1.42      // wrist, in bodyW
    static let finger: CGFloat = 0.11       // in radius
    static let eyeOffset: CGFloat = 0.33    // in bodyW
    static let lens: CGFloat = 0.40         // in radius
    static let templeSpan: CGFloat = 2.06   // hook end, in lensR
    static let hip: CGFloat = 0.80          // in bodyH
    static let legLength: CGFloat = 0.46    // in radius, before sag shortens it
    static let shadow: CGFloat = 0.16       // centre offset plus half height

    private static let widestBody: CGFloat = 1.30 + maxSpread
    private static let tallestBody: CGFloat = 1.06

    static var halfWidth: CGFloat {
        max(widestBody * armSpan + finger,
            max(widestBody * lump + contour,
                widestBody * eyeOffset + lens * templeSpan))
    }

    /// Crown. Measured with the *tallest* body, which is the unspread one.
    static var above: CGFloat { tallestBody * lump + contour }

    /// Shadow's lower edge. Sag moves the whole creature down faster than it shortens
    /// the legs, so the worst case is the most slumped stage.
    static var below: CGFloat {
        tallestBody * hip + (legLength - maxSag * 0.7) + shadow + maxSag
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
        let palette = Palette(stage: stage)

        let cx = size.width / 2

        // Fit the *whole* creature, not the head — and fit the *widest* stage, not this
        // one. `Reach` computes the extents from the same constants the limbs and body
        // use, so lengthening an arm moves the fit automatically.
        //
        // Hand-computing this is how the hands got clipped, twice. The first time a glove
        // grew past a hardcoded fraction. The second time the arithmetic was redone for
        // `crisp` and never checked against `mush`, which spreads 16% wider — the
        // fingertips reached 2.18 × radius against a budget of 2.00, and SwiftUI would
        // have cut them off in the two stages that need to look worst.
        let radius = min(
            size.width * 0.5 / Reach.halfWidth,
            min(size.height * 0.42 / Reach.above, size.height * 0.58 / Reach.below)
        )

        // Idle breathing: slow, small, and the only thing that moves at rest.
        let breathe = CGFloat(sin(time * 0.9)) * radius * 0.014
        let tremor = p.jitter > 0 ? CGFloat(sin(time * 17)) * radius * p.jitter * 0.5 : 0
        let cy = size.height * 0.42 + radius * p.sag + breathe

        let bodyW = radius * (1.30 + p.spread)
        let bodyH = radius * (1.06 - p.spread * 0.30)
        let center = CGPoint(x: cx + tremor, y: cy)

        // Level of detail. Not a blur budget any more — there are no blurs left — but at
        // Dynamic Island size the fold lines and sheen strokes collapse into a smudge and
        // are better dropped than drawn.
        let detail = min(size.width, size.height) >= 96

        // Same arithmetic the legs use, so the shadow cannot drift away from the feet.
        let groundY = center.y + bodyH * 0.80 + radius * (0.46 - p.sag * 0.7) + radius * 0.10
        drawShadow(&context, center: center, groundY: groundY, bodyW: bodyW, radius: radius)
        drawLegs(&context, center: center, bodyH: bodyH, bodyW: bodyW, radius: radius, palette: palette)
        drawArms(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time)
        drawBody(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, detail: detail)
        drawFace(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time, detail: detail)
    }

    // MARK: Ground

    /// Flat, not blurred. A soft shadow under a flat drawing is the single easiest way to
    /// make it look like two different illustrations stapled together.
    private func drawShadow(
        _ context: inout GraphicsContext, center: CGPoint, groundY: CGFloat,
        bodyW: CGFloat, radius: CGFloat
    ) {
        let rect = CGRect(
            x: center.x - bodyW * 0.58, y: groundY - radius * 0.06,
            width: bodyW * 1.16, height: radius * 0.12
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .color(Token.Color.groundDeep.opacity(0.42 - Double(p.sag) * 0.5))
        )
    }

    // MARK: Limbs

    /// Spindly. One thin round-capped stroke, no highlight, no glove, no shoe — the whole
    /// charm of the reference is a heavy body on wire limbs, and thickening them to make
    /// them "readable" is exactly what kills it.
    ///
    /// Floored at 1.2pt because below about a point a stroke stops anti-aliasing into
    /// anything and the limbs vanish from the widget.
    private func limbWidth(_ radius: CGFloat) -> CGFloat { max(radius * 0.052, 1.2) }

    private func stroke(
        _ context: inout GraphicsContext, _ path: Path, _ colour: Color, _ width: CGFloat
    ) {
        context.stroke(path, with: .color(colour),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func drawLegs(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyH: CGFloat, bodyW: CGFloat, radius: CGFloat, palette: Palette
    ) {
        let hipY = center.y + bodyH * 0.80
        let footY = hipY + radius * (0.46 - p.sag * 0.7)
        let spread = bodyW * (0.26 + p.spread * 1.1)
        let width = limbWidth(radius)

        for side in [-1.0, 1.0] as [CGFloat] {
            let x0 = center.x + side * bodyW * 0.18
            let x1 = center.x + side * spread

            var leg = Path()
            leg.move(to: CGPoint(x: x0, y: hipY))
            leg.addLine(to: CGPoint(x: x1, y: footY))
            // The foot is a kink in the same line, not an object. Outward, so the stance
            // reads as planted rather than pigeon-toed.
            leg.addLine(to: CGPoint(x: x1 + side * radius * 0.17, y: footY - radius * 0.015))
            stroke(&context, leg, palette.ink, width)
        }
    }

    private func drawArms(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette, time: TimeInterval
    ) {
        let drop = p.arms
        let sway = CGFloat(sin(time * 0.7)) * 0.03
        let width = limbWidth(radius)

        for side in [-1.0, 1.0] as [CGFloat] {
            let shoulder = CGPoint(x: center.x + side * bodyW * 0.74, y: center.y + bodyH * 0.26)
            let elbow = CGPoint(
                x: center.x + side * bodyW * (1.18 - drop * 0.08),
                y: shoulder.y + radius * (0.02 + drop * 0.26)
            )
            let wrist = CGPoint(
                x: center.x + side * bodyW * (1.42 - drop * 0.16),
                y: shoulder.y + radius * (0.22 + drop * 0.62 + sway)
            )

            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: elbow)
            arm.addLine(to: wrist)
            stroke(&context, arm, palette.ink, width)

            // Three fingers, fanned along the direction the forearm is already travelling.
            // A dot on the end of a stick reads as a pin; three short strokes read as a
            // hand, and cost four lines of maths.
            let heading = atan2(Double(wrist.y - elbow.y), Double(wrist.x - elbow.x))
            for finger in -1...1 {
                let angle = heading + Double(finger) * 0.44
                var digit = Path()
                digit.move(to: wrist)
                digit.addLine(to: CGPoint(
                    x: wrist.x + CGFloat(cos(angle)) * radius * 0.11,
                    y: wrist.y + CGFloat(sin(angle)) * radius * 0.11
                ))
                stroke(&context, digit, palette.ink, width * 0.85)
            }
        }
    }

    // MARK: Body

    /// The silhouette, sampled rather than drawn with four beziers.
    ///
    /// A brain's outline is *lumpy* — the folds reach the edge and push it out — so the
    /// radius carries two small harmonics on top of the ellipse. Harmonics 7 and 11 are
    /// mutually prime, so the bumps never line up into a regular rosette the way 4-and-8
    /// would. Amplitudes are larger than the moulded version used, because a flat drawing
    /// has no shading to describe the lobes and the contour has to do all of it.
    private func bodyPath(center c: CGPoint, bodyW w: CGFloat, bodyH h: CGFloat) -> Path {
        var path = Path()
        let steps = 120

        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi - .pi / 2

            // Harmonic 6 carries the lobes and 11 breaks up the regularity. The first
            // version used 7 and 11 at half this amplitude and the silhouette read as a
            // rock: too many bumps, none of them big enough to be a lobe.
            let lumps = 1
                + 0.072 * sin(angle * 6 + 0.9)
                + 0.020 * sin(angle * 11 - 0.4)

            // Crown dip: the longitudinal fissure pulls the top centre down. Narrow, so
            // it reads as a cleft rather than a flat top.
            let fromTop = abs(atan2(sin(angle + .pi / 2), cos(angle + .pi / 2)))
            let dip = 1 - 0.105 * exp(-pow(fromTop / 0.30, 2))

            let rx = w * CGFloat(lumps * dip)
            let ry = h * CGFloat(lumps * dip)
            let point = CGPoint(
                x: c.x + rx * CGFloat(cos(angle)),
                y: c.y + ry * CGFloat(sin(angle))
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func drawBody(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette, detail: Bool
    ) {
        let silhouette = bodyPath(center: center, bodyW: bodyW, bodyH: bodyH)

        context.fill(silhouette, with: .color(palette.base))

        // Folds and sheen live inside the contour, so the contour is stroked last and
        // stays a clean unbroken edge.
        context.drawLayer { layer in
            layer.clip(to: silhouette)
            if detail {
                drawFolds(&layer, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius, palette: palette)
                drawSheen(&layer, center: center, bodyW: bodyW, bodyH: bodyH,
                          radius: radius, palette: palette)
            }
        }

        context.stroke(
            silhouette, with: .color(palette.ink),
            style: StrokeStyle(lineWidth: max(radius * 0.072, 1.4), lineJoin: .round)
        )
    }

    /// Deterministic pseudo-random. The same fold pattern every frame and every launch —
    /// a creature whose brain rearranged itself between frames would read as noise.
    private func rnd(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 127.1 + 311.7) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    /// The folds, as ink lines.
    ///
    /// Twelve of them, not thirty-six. The moulded version stroked every fold three times
    /// — blurred groove, fold, blurred crest — because it was describing a surface. A flat
    /// drawing describes a *boundary*, so one thin line each, longer and more bowed, and
    /// far fewer: at this weight anything denser turns the body into hatching.
    private func drawFolds(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette
    ) {
        // Keep out of the face. Without this the folds ran straight through the glasses
        // and the mouth vanished into them — the drawing read as a cracked rock with eyes
        // rather than as a creature. Elliptical, so the exclusion follows the face's own
        // shape instead of cutting a rectangle out of the folds.
        let faceY = center.y + bodyH * 0.10
        let faceRX = bodyW * 0.33 + radius * 0.52
        let faceRY = radius * 1.00
        func clearsFace(_ point: CGPoint) -> Bool {
            let dx = (point.x - center.x) / faceRX
            let dy = (point.y - faceY) / faceRY
            return dx * dx + dy * dy > 1
        }

        let width = max(bodyW * 0.038, 1)
        let style = StrokeStyle(lineWidth: width, lineCap: .round)

        for side in [-1.0, 1.0] as [CGFloat] {
            for ring in 0..<2 {
                let count = 3
                for index in 0..<count {
                    let seed = ring * 17 + index * 5 + (side > 0 ? 101 : 3)
                    let j1 = rnd(seed) - 0.5
                    let j2 = rnd(seed + 41) - 0.5

                    // Polar position inside the hemisphere. `radial` 0 is the fissure,
                    // 1 the outer edge; `arc` sweeps from crown to base.
                    let radial = 0.34 + CGFloat(ring) * 0.30 + j1 * 0.08
                    let arc = (CGFloat(index) + 0.5) / CGFloat(count) * 1.7 - 0.35 + j2 * 0.12

                    let px = center.x + side * bodyW * radial * CGFloat(cos(Double(arc) - 0.35))
                    let py = center.y - bodyH * 0.70 + bodyH * 1.80 * arc / 1.7 + bodyH * j2 * 0.06

                    // Tangential: perpendicular to the line out from the centre, so folds
                    // wrap the dome rather than cutting across it.
                    let theta = atan2(Double(py - center.y), Double(px - center.x)) + .pi / 2
                    let length = bodyW * (0.26 + rnd(seed + 7) * 0.12)

                    let ax = px - CGFloat(cos(theta)) * length / 2
                    let ay = py - CGFloat(sin(theta)) * length / 2
                    let bx = px + CGFloat(cos(theta)) * length / 2
                    let by = py + CGFloat(sin(theta)) * length / 2
                    // Bow outward from the centre, the direction a fold bulges.
                    let bow = length * (0.44 + rnd(seed + 13) * 0.20)
                    let cxp = px + CGFloat(cos(theta - .pi / 2)) * bow * side
                    let cyp = py + CGFloat(sin(theta - .pi / 2)) * bow * side

                    guard clearsFace(CGPoint(x: px, y: py)) else { continue }

                    var fold = Path()
                    fold.move(to: CGPoint(x: ax, y: ay))
                    fold.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: cxp, y: cyp))
                    context.stroke(fold, with: .color(palette.ink.opacity(0.85)), style: style)
                }
            }
        }

        // Longitudinal fissure: the one line that splits the two halves, and the only fold
        // drawn at full strength.
        var fissure = Path()
        fissure.move(to: CGPoint(x: center.x, y: center.y - bodyH * 1.02))
        fissure.addCurve(
            to: CGPoint(x: center.x, y: center.y - bodyH * 0.34),
            control1: CGPoint(x: center.x + bodyW * 0.05, y: center.y - bodyH * 0.80),
            control2: CGPoint(x: center.x - bodyW * 0.05, y: center.y - bodyH * 0.52)
        )
        context.stroke(
            fissure, with: .color(palette.ink),
            style: StrokeStyle(lineWidth: width * 1.15, lineCap: .round)
        )
    }

    /// Three flat white strokes on the upper left, following the lobe curvature.
    ///
    /// This is the flat-drawing substitute for a specular highlight, and it is doing the
    /// same job: saying which way the light comes from. It stays on one side for exactly
    /// that reason — sheen sprinkled evenly is glitter, not light.
    private func drawSheen(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette
    ) {
        guard p.sheen > 0.08 else { return }
        let style = StrokeStyle(lineWidth: max(radius * 0.062, 1), lineCap: .round)
        let marks: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.62, -0.60, 0.34),
            (-0.30, -0.82, 0.26),
            (-0.80, -0.24, 0.22)
        ]

        for (mx, my, length) in marks {
            let start = CGPoint(x: center.x + bodyW * mx, y: center.y + bodyH * my)
            let end = CGPoint(
                x: start.x + bodyW * length * 0.75,
                y: start.y - bodyH * length * 0.30
            )
            let control = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2 - bodyH * length * 0.34
            )
            var mark = Path()
            mark.move(to: start)
            mark.addQuadCurve(to: end, control: control)
            context.stroke(
                mark, with: .color(palette.shine.opacity(Double(0.62 * p.sheen))), style: style
            )
        }
    }

    // MARK: Face

    private func drawFace(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette,
        time: TimeInterval, detail: Bool
    ) {
        // The face sits just below centre, the way the reference's does, and the lens is
        // now clearly larger than the eye it holds. At 0.375 against an eye of 0.205 the
        // wide-eyed `buzzed` sclera pushed past the rim and the frames read as goggles.
        let eyeY = center.y + bodyH * 0.10
        let eyeX = bodyW * 0.33
        let lensR = radius * 0.40
        let rx = radius * 0.185
        let ry = rx * 1.04 * p.open

        // Blink. Cheap, and most of what makes something read as alive.
        //
        // Guarded on `time > 0` because a static render passes zero, and zero sits inside
        // the blink window — which had every widget and Dynamic Island drawing the
        // creature with its eyes shut.
        let cycle = time.truncatingRemainder(dividingBy: p.blinkInterval)
        let blink: CGFloat = (time > 0 && cycle < 0.12) ? 0.08 : 1

        drawBlush(&context, center: center, eyeX: eyeX, eyeY: eyeY,
                  lensR: lensR, radius: radius, palette: palette)

        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX
            drawEye(&context, ex: ex, eyeY: eyeY, rx: rx, ry: ry, blink: blink,
                    side: side, time: time, palette: palette)
        }

        drawMouth(&context, center: center, eyeY: eyeY, radius: radius, palette: palette)

        // Glasses over the eyes, brows over the glasses — the order a real pair sits in.
        drawGlasses(&context, center: center, eyeX: eyeX, eyeY: eyeY,
                    lensR: lensR, radius: radius, palette: palette, detail: detail)
        drawBrows(&context, center: center, eyeX: eyeX, eyeY: eyeY,
                  lensR: lensR, radius: radius, palette: palette)
    }

    private func drawBlush(
        _ context: inout GraphicsContext, center: CGPoint, eyeX: CGFloat, eyeY: CGFloat,
        lensR: CGFloat, radius: CGFloat, palette: Palette
    ) {
        guard p.sheen > 0.2 else { return }
        let w = radius * 0.30
        let h = radius * 0.17
        for side in [-1.0, 1.0] as [CGFloat] {
            let cxp = center.x + side * (eyeX + radius * 0.12)
            let rect = CGRect(x: cxp - w / 2, y: eyeY + lensR * 1.05 - h / 2, width: w, height: h)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(palette.blush.opacity(Double(0.55 + 0.25 * p.sheen)))
            )
        }
    }

    private func drawEye(
        _ context: inout GraphicsContext, ex: CGFloat, eyeY: CGFloat,
        rx: CGFloat, ry: CGFloat, blink: CGFloat, side: CGFloat,
        time: TimeInterval, palette: Palette
    ) {
        let sclera = CGRect(x: ex - rx, y: eyeY - ry * blink,
                            width: rx * 2, height: ry * blink * 2)
        context.fill(Path(ellipseIn: sclera), with: .color(Token.Color.specular))

        guard blink > 0.5 else { return }

        // Buzzed cannot hold a gaze.
        let gaze = p.jitter > 0 ? CGFloat(sin(time * 5.3 + Double(side))) * rx * 0.14 : 0
        let irisR = rx * 0.78
        let ix = ex + gaze
        let iy = eyeY + ry * 0.05

        // Flat discs, no radial gradient. The blue is a *ring* around a large pupil, which
        // is what an eye behind a lens actually looks like at this scale, and it keeps the
        // one blue in the system (brand.json component_rules.eyes) without the eye turning
        // into a marble.
        context.fill(
            Path(ellipseIn: CGRect(x: ix - irisR, y: iy - irisR,
                                   width: irisR * 2, height: irisR * 2)),
            with: .color(Token.Color.eyeIris)
        )

        let pupilR = irisR * (0.94 - p.pupil * 0.5)
        context.fill(
            Path(ellipseIn: CGRect(x: ix - pupilR, y: iy - pupilR,
                                   width: pupilR * 2, height: pupilR * 2)),
            with: .color(Token.Color.eyePupil)
        )

        let glintR = irisR * 0.28
        context.fill(
            Path(ellipseIn: CGRect(x: ix - irisR * 0.30 - glintR, y: iy - irisR * 0.38 - glintR,
                                   width: glintR * 2, height: glintR * 2)),
            with: .color(Token.Color.specular)
        )

        // Heavy lid, in the body colour, so it reads as the brain closing over the eye
        // rather than a grey bar laid on top.
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

    /// Round wire frames: two rings, a bowed bridge, and a temple arm with a hook.
    ///
    /// The hook is not decoration. Without it the temple ends in mid-air and the glasses
    /// read as two circles someone drew on the face; with it they read as an object that
    /// goes round the back of a head.
    private func drawGlasses(
        _ context: inout GraphicsContext, center: CGPoint, eyeX: CGFloat, eyeY: CGFloat,
        lensR: CGFloat, radius: CGFloat, palette: Palette, detail: Bool
    ) {
        let wire = max(radius * 0.050, 1.2)
        let style = StrokeStyle(lineWidth: wire, lineCap: .round, lineJoin: .round)

        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX
            let lens = CGRect(x: ex - lensR, y: eyeY - lensR, width: lensR * 2, height: lensR * 2)
            context.stroke(Path(ellipseIn: lens), with: .color(palette.ink), style: style)

            // A single diagonal glint says "there is glass here". Skipped at widget size,
            // where it lands on the same pixel as the pupil's own glint.
            if detail {
                var glint = Path()
                glint.move(to: CGPoint(x: ex - lensR * 0.52, y: eyeY + lensR * 0.10))
                glint.addLine(to: CGPoint(x: ex - lensR * 0.10, y: eyeY - lensR * 0.50))
                context.stroke(
                    glint, with: .color(Token.Color.specular.opacity(0.42)),
                    style: StrokeStyle(lineWidth: wire * 0.9, lineCap: .round)
                )
            }

            // Temple: out and slightly up, then a short hook down.
            var temple = Path()
            let start = CGPoint(x: ex + side * lensR * 0.96, y: eyeY - lensR * 0.30)
            let hinge = CGPoint(x: ex + side * lensR * 1.90, y: eyeY - lensR * 0.72)
            temple.move(to: start)
            temple.addQuadCurve(
                to: hinge,
                control: CGPoint(x: ex + side * lensR * 1.44, y: eyeY - lensR * 0.74)
            )
            temple.addQuadCurve(
                to: CGPoint(x: hinge.x + side * lensR * 0.16, y: hinge.y + lensR * 0.30),
                control: CGPoint(x: hinge.x + side * lensR * 0.30, y: hinge.y + lensR * 0.04)
            )
            context.stroke(temple, with: .color(palette.ink), style: style)
        }

        // Bridge, bowed upward between the two rings.
        var bridge = Path()
        bridge.move(to: CGPoint(x: center.x - eyeX + lensR * 0.94, y: eyeY - lensR * 0.20))
        bridge.addQuadCurve(
            to: CGPoint(x: center.x + eyeX - lensR * 0.94, y: eyeY - lensR * 0.20),
            control: CGPoint(x: center.x, y: eyeY - lensR * 0.62)
        )
        context.stroke(bridge, with: .color(palette.ink), style: style)
    }

    private func drawBrows(
        _ context: inout GraphicsContext, center: CGPoint, eyeX: CGFloat, eyeY: CGFloat,
        lensR: CGFloat, radius: CGFloat, palette: Palette
    ) {
        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX
            context.drawLayer { layer in
                layer.translateBy(x: ex, y: eyeY - lensR - radius * (0.07 + p.browLift))
                layer.rotate(by: .radians(Double(side * p.browTilt)))
                let bw = lensR * 1.20
                var brow = Path()
                brow.move(to: CGPoint(x: -bw * 0.5, y: radius * 0.022))
                brow.addQuadCurve(
                    to: CGPoint(x: bw * 0.5, y: radius * 0.014),
                    control: CGPoint(x: 0, y: -radius * 0.050)
                )
                layer.stroke(
                    brow, with: .color(palette.ink),
                    style: StrokeStyle(lineWidth: max(radius * 0.078, 1.4), lineCap: .round)
                )
            }
        }
    }

    /// Above 0.15 the mouth opens — a filled shape with a tongue and one tooth. Below, it
    /// is a single stroked curve that turns down as the number falls.
    ///
    /// The open mouth is reserved for the good stages on purpose. An open smile is the
    /// loudest thing on the face, and a creature grinning through a bad day is the exact
    /// coach tone `brand.json` forbids.
    private func drawMouth(
        _ context: inout GraphicsContext, center: CGPoint, eyeY: CGFloat,
        radius: CGFloat, palette: Palette
    ) {
        let my = eyeY + radius * 0.64

        guard p.mouth > 0.15 else {
            let mw = radius * 0.21
            var line = Path()
            line.move(to: CGPoint(x: center.x - mw, y: my))
            line.addQuadCurve(
                to: CGPoint(x: center.x + mw, y: my),
                control: CGPoint(x: center.x, y: my + radius * 0.34 * p.mouth)
            )
            context.stroke(
                line, with: .color(palette.ink),
                style: StrokeStyle(lineWidth: max(radius * 0.058, 1.2), lineCap: .round)
            )
            return
        }

        let mw = radius * (0.19 + 0.09 * p.mouth)
        let depth = radius * (0.16 + 0.24 * p.mouth)

        var shape = Path()
        shape.move(to: CGPoint(x: center.x - mw, y: my))
        shape.addQuadCurve(
            to: CGPoint(x: center.x + mw, y: my),
            control: CGPoint(x: center.x, y: my - depth * 0.18)
        )
        shape.addQuadCurve(
            to: CGPoint(x: center.x - mw, y: my),
            control: CGPoint(x: center.x, y: my + depth * 2.1)
        )
        shape.closeSubpath()
        context.fill(shape, with: .color(palette.ink))

        context.drawLayer { layer in
            layer.clip(to: shape)
            // Tongue, resting on the lower lip.
            let tongue = CGRect(
                x: center.x - mw * 0.62, y: my + depth * 0.44,
                width: mw * 1.24, height: depth * 1.5
            )
            layer.fill(Path(ellipseIn: tongue), with: .color(palette.tongue))
            // One tooth on the upper lip. Two would read as a grimace.
            let tooth = CGRect(
                x: center.x - mw * 0.34, y: my - depth * 0.10,
                width: mw * 0.62, height: depth * 0.34
            )
            layer.fill(Path(tooth), with: .color(Token.Color.specular))
        }
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
