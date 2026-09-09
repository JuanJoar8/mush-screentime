import SwiftUI
import MushKit

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

/// Where the light comes from, as a unit vector in screen space.
///
/// One constant, used by every part of the drawing — the body's key light, the groove
/// each gyrus casts, the lit edge of a wire frame, the direction the cast shadow falls.
/// That is most of why the creature reads as an object rather than as a picture of one:
/// a sheen on the upper left over a shadow that also falls upper left is the tell that
/// nothing was actually modelled.
///
/// Upper left, because the app's own panels are lit that way and a character lit from
/// somewhere else looks pasted onto the screen.
private enum Light {
    static let dx: CGFloat = -0.62
    static let dy: CGFloat = -0.78
    /// Away from the light: grooves, cast shadows, the turning edge.
    static let awayX: CGFloat = 0.62
    static let awayY: CGFloat = 0.78
}

/// The shades one stage needs, all derived from its single token.
///
/// Eleven entries, where the flat version had five. That is the cost of modelling: a
/// solid fill needs one colour, a lit surface needs a lit value, a mid value, a turn,
/// and a floor for the places light does not reach.
///
/// Every one is built with `Color.mix(with:by:)` from `stage.tint` and the system
/// tokens. The token contract says a colour literal in a view is a bug, and mixing keeps
/// all eleven tied to the one value in `brand.json` — change the stage tint and the whole
/// material follows.
private struct Palette {
    /// Crest of a gyrus, and the core of the key light.
    let lit: Color
    /// The body's mid tone. The tint itself.
    let base: Color
    /// A gyrus's own body: barely above the ground it sits on, which is what makes the
    /// groove and the crest do the describing rather than the fill.
    let gyrus: Color
    /// The surface turning away from the light.
    let shade: Color
    /// Sulcus floor and ambient occlusion. The darkest surface colour.
    let deep: Color
    /// The contour. Darker than `deep`, so the edge still reads once the form is shaded.
    let ink: Color
    /// Cheeks. Warmed toward `bad`, the only warm red in the system.
    let blush: Color
    /// Specular white.
    let shine: Color
    /// Light bouncing off the floor onto the creature's underside. It is the *ground's*
    /// own colour, which is what a bounce actually is — and it is what ties the creature to
    /// the surface it stands on instead of floating above it.
    let bounce: Color
    /// Lens glass.
    let glass: Color
    let tongue: Color

    init(stage: BrainStage) {
        let tint = stage.tint
        base = tint

        // Warmed *before* it is darkened, at every level. Mixing a tint straight toward
        // the shade anchor desaturates it on the way: the amber stage came out olive and
        // the grey stages came out dead. A touch of `bad` first keeps every shade a
        // deeper version of the body colour rather than a grey one.
        //
        // Toward `shadeAnchor`, **not** toward the ground. Darkening toward the background
        // worked for exactly as long as the background was night: the flip to a light
        // theme turned every one of these mixes into a *lightening* one, and the contour
        // would have dissolved into the body with no test able to see it. An explicit
        // shade anchor makes the derivation independent of the theme.
        let warm = tint.mix(with: Token.Color.bad, by: 0.20)
        lit = tint.mix(with: Token.Color.specular, by: 0.42)
        gyrus = tint.mix(with: Token.Color.specular, by: 0.13)
        shade = warm.mix(with: Token.Color.shadeAnchor, by: 0.22)
        deep = warm.mix(with: Token.Color.shadeAnchor, by: 0.44)
        ink = warm.mix(with: Token.Color.shadeAnchor, by: 0.62)

        blush = tint.mix(with: Token.Color.bad, by: 0.52)
        shine = Token.Color.specular
        bounce = Token.Color.ground
        glass = Token.Color.eyeIris.mix(with: Token.Color.specular, by: 0.62)
        tongue = Token.Color.bad.mix(with: Token.Color.shadeAnchor, by: 0.10)
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
    /// Silhouette harmonics, at their peak: 1 + 0.048 + 0.018.
    static let lump: CGFloat = 1.066
    /// Half the contour stroke.
    static let contour: CGFloat = 0.032

    static let armSpan: CGFloat = 1.18      // wrist, in bodyW
    /// Half the limb stroke. `limbWidth` is `radius * 0.075` and the cap is round, so ink
    /// reaches this far past the point the arithmetic places the wrist.
    ///
    /// It exists because `Reach` is written as a guarantee for any frame, and half a
    /// stroke width past a hand-derived budget is precisely how the hands got clipped the
    /// last two times. `scripts/check-fit.js` measures what this claims.
    static let limbCap: CGFloat = 0.0375    // in radius
    static let eyeOffset: CGFloat = 0.285   // in bodyW
    static let lens: CGFloat = 0.42         // in radius
    static let templeSpan: CGFloat = 2.06   // hook end, in lensR
    static let hip: CGFloat = 0.84          // in bodyH
    static let legLength: CGFloat = 0.36    // in radius, before sag shortens it
    /// Centre offset, half height, *and* the blur that softens it. The shadow is the one
    /// blurred shape below the creature, and a blur radius is extra extent — the flat
    /// version had none to account for.
    static let shadow: CGFloat = 0.30

    // Motifs sit *outside* the silhouette, so they have their own reach, and until now
    // they had none — they were simply smaller than whatever slack the old proportions
    // happened to leave. `scripts/check-fit.js` caught both the first time it ran against
    // the new ones: the healing sparkle 0.1px from the top edge, the fallen drip 0.8px
    // from the bottom. Neither was luck anybody had chosen.
    //
    // Both numbers come from the motif tables themselves. The bloom factor is 1.70, not
    // the 1.15 the bloom ellipse is drawn at, because the bloom is *blurred*: a blur
    // spreads a shape past its own edge, and a budget that only counts geometry is the
    // same mistake as a shadow budget with no blur allowance.
    static let sparkleSpan: CGFloat = 1.16        // widest star centre, in bodyW
    static let sparkleTop: CGFloat = 1.06         // highest star centre, in bodyH
    static let sparkleWide: CGFloat = 0.230       // 0.135 * 1.70, in radius
    static let sparkleHigh: CGFloat = 0.128       // 0.075 * 1.70, in radius
    static let dripTop: CGFloat = 0.70            // where a drip leaves the body, in bodyH
    static let dripDrop: CGFloat = 0.680          // fallen droplet's lower edge, in radius

    private static let widestBody: CGFloat = 1.38 + maxSpread
    private static let tallestBody: CGFloat = 0.99

    static var halfWidth: CGFloat {
        max(max(widestBody * armSpan + limbCap,
                widestBody * sparkleSpan + sparkleWide),
            max(widestBody * lump + contour,
                widestBody * eyeOffset + lens * templeSpan))
    }

    /// Crown, or the highest sparkle. Measured with the *tallest* body, the unspread one.
    static var above: CGFloat {
        max(tallestBody * lump + contour, tallestBody * sparkleTop + sparkleHigh)
    }

    /// Whichever reaches lowest — the cast shadow under the feet, or a drip that has
    /// already fallen off the body. Sag moves the whole creature down faster than it
    /// shortens the legs, so the worst case is the most slumped stage either way.
    static var below: CGFloat {
        max(tallestBody * hip + (legLength - maxSag * 0.7) + shadow,
            tallestBody * dripTop + dripDrop) + maxSag
    }
}

/// The character: an anthropomorphic brain in round wire glasses, modelled rather than
/// drawn flat.
///
/// No image assets. Every curve is generated from `BrainStage`, so the creature cannot
/// drift out of sync with the number beside it — change the stage and the whole drawing
/// follows: colour, material, posture, brow angle, gaze, how far the mouth opens.
///
/// **The volume comes from the anatomy, not from a gradient.** There was an earlier
/// moulded version and it was killed for good reason: a smooth egg with a radial gradient
/// and thirty blurred layers on top, which is what every stock 3D render is, and no amount
/// of blur made it a brain. This one is built the other way round. Each gyrus is a *ridge*
/// with its own groove below it, its own body and its own crest — the folds make the form,
/// and the two global gradients only say where the light is. That is why this one is
/// complex where the old one was merely expensive.
///
/// **Five stages, two materials.** `crisp` is firm wet tissue: deep sulci, a tight
/// specular, a teal bounce off the ground. `mush` is a matte slumped dome — sulci smeared
/// almost flat, specular gone, surface cracked. The parameters that carry this are
/// `turgor` (how far a fold stands proud) and `gloss` (how tight the highlight is), and
/// they are what makes a stage a *condition* rather than a mood.
///
/// **The glasses are the signature.** Round wire frames, and now real objects: the lens
/// carries a glass tint and two streak highlights, the wire has a lit upper edge, and the
/// frame casts a shadow onto the brain behind it. They are drawn over the eyes, exactly
/// as a real pair sits.
///
/// **The brows do the acting.** Tilt and lift on two short strokes carry almost all of
/// the expression, which is why they are the parameters that move most between stages.
///
/// Note the progression is not a dimmer switch. `buzzed` sits in the middle and is the
/// *most agitated* state — small pupils, wide eyes, a fine tremor — because that is what
/// an overstimulated afternoon actually feels like.
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
        // fingertips reached 2.18 x radius against a budget of 2.00, and SwiftUI would
        // have cut them off in the two stages that need to look worst.
        let radius = min(
            size.width * 0.5 / Reach.halfWidth,
            min(size.height * 0.42 / Reach.above, size.height * 0.58 / Reach.below)
        )

        // Idle breathing: slow, small, and the only thing that moves at rest.
        let breathe = CGFloat(sin(time * 0.9)) * radius * 0.014
        let tremor = p.jitter > 0 ? CGFloat(sin(time * 17)) * radius * p.jitter * 0.5 : 0
        let cy = size.height * 0.42 + radius * p.sag + breathe

        // Wider than tall, which is the single proportion that separates a brain from a
        // ball. The face sits low in it, the way a small creature's does.
        let bodyW = radius * (1.38 + p.spread)
        let bodyH = radius * (0.99 - p.spread * 0.30)
        let center = CGPoint(x: cx + tremor, y: cy)

        // Level of detail. Below this the gyri collapse into a smudge, the two streaks on
        // a lens land on the same pixel, and the specular is sub-pixel — so the small
        // render keeps the global gradients, which are what make even a 20pt blob read as
        // a solid object, and drops everything that would only add noise.
        //
        // 64, not 96. Fold density is the difference between rot and healing, so a
        // thumbnail that drops the folds drops the one thing it is there to show — and
        // the stage ladder on the brain screen is exactly that thumbnail. The Dynamic
        // Island sits near 40pt and stays below the line, which is what the line is for.
        let detail = min(size.width, size.height) >= 64

        // Same arithmetic the legs use, so the shadow cannot drift away from the feet.
        let groundY = center.y + bodyH * 0.84 + radius * (0.36 - p.sag * 0.7) + radius * 0.10
        drawShadow(&context, center: center, groundY: groundY, bodyW: bodyW,
                   radius: radius, detail: detail)
        drawLegs(&context, center: center, bodyH: bodyH, bodyW: bodyW, radius: radius, palette: palette)
        drawArms(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time)
        drawBody(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, detail: detail)
        drawFace(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius,
                 palette: palette, time: time, detail: detail)

        // Last, and outside the silhouette. These are the props, and a prop drawn under
        // the creature is just a smudge.
        if detail && p.motifs.contains(.sweat) {
            drawSweat(&context, center: center, bodyW: bodyW, bodyH: bodyH, radius: radius)
        }
        if detail && p.motifs.contains(.sparkle) {
            drawSparkles(&context, center: center, bodyW: bodyW, bodyH: bodyH,
                         radius: radius, time: time)
        }
    }

    // MARK: Ground

    /// Two shapes, not one. A single hard ellipse is what makes a flat drawing sit on the
    /// page; a single soft one makes it float. Real contact is both — a wide soft pool
    /// that says where the light is blocked, and a small dark core right under the feet
    /// that says the feet are actually touching.
    ///
    /// **On a light ground this is the whole separation budget.** The dark theme had a cool
    /// rim doing that job, and a rim needs something darker behind it to glow against; over
    /// a near-white viewport there is nothing, so the rim was removed rather than left in
    /// at an invisible weight. The rule was never "always a rim" — it was "the object
    /// separates from its ground", and the means changes with the ground.
    ///
    /// The pool is offset *away* from the light, like everything else in the drawing.
    private func drawShadow(
        _ context: inout GraphicsContext, center: CGPoint, groundY: CGFloat,
        bodyW: CGFloat, radius: CGFloat, detail: Bool
    ) {
        let slump = 0.34 - Double(p.sag) * 0.4
        let offset = Light.awayX * radius * 0.10

        let pool = CGRect(
            x: center.x - bodyW * 0.66 + offset, y: groundY - radius * 0.09,
            width: bodyW * 1.32, height: radius * 0.19
        )
        if detail {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: radius * 0.095))
                layer.fill(Path(ellipseIn: pool),
                           with: .color(Token.Color.shadeAnchor.opacity(slump * 0.80)))
            }
        } else {
            context.fill(Path(ellipseIn: pool),
                         with: .color(Token.Color.shadeAnchor.opacity(slump * 0.60)))
        }

        let contact = CGRect(
            x: center.x - bodyW * 0.32 + offset * 0.5, y: groundY - radius * 0.040,
            width: bodyW * 0.64, height: radius * 0.08
        )
        context.fill(Path(ellipseIn: contact),
                     with: .color(Token.Color.shadeAnchor.opacity(slump * 1.15)))
    }

    // MARK: Limbs

    /// Short and thick, and the round cap *is* the hand. Three fanned digits used to sit
    /// on the end of each wrist so it would read as a hand rather than a pin, and at wire
    /// thickness that was right. At this weight the cap already reads as a mitten, and
    /// three lines coming off it read as a rake — so the digits are gone rather than kept
    /// at a size that fights the limb they hang from.
    ///
    /// Floored at 1.6pt because below about a point a stroke stops anti-aliasing into
    /// anything and the limbs vanish from the widget.
    private func limbWidth(_ radius: CGFloat) -> CGFloat { max(radius * 0.075, 1.6) }

    private func stroke(
        _ context: inout GraphicsContext, _ path: Path, _ colour: Color, _ width: CGFloat
    ) {
        context.stroke(path, with: .color(colour),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// A limb, twice: the full-weight dark stroke, then a thinner lit stroke shifted
    /// toward the light. Two strokes turn a flat line into a cylinder, and it is the
    /// cheapest volume in the whole drawing.
    private func strokeLimb(
        _ context: inout GraphicsContext, _ path: Path, _ palette: Palette, _ width: CGFloat
    ) {
        stroke(&context, path, palette.ink, width)
        context.drawLayer { layer in
            layer.translateBy(x: Light.dx * width * 0.24, y: Light.dy * width * 0.24)
            layer.stroke(
                path, with: .color(palette.lit.opacity(0.45)),
                style: StrokeStyle(lineWidth: width * 0.34, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawLegs(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyH: CGFloat, bodyW: CGFloat, radius: CGFloat, palette: Palette
    ) {
        let hipY = center.y + bodyH * 0.84
        let footY = hipY + radius * (0.36 - p.sag * 0.7)
        let spread = bodyW * (0.30 + p.spread * 1.1)
        let width = limbWidth(radius)

        for side in [-1.0, 1.0] as [CGFloat] {
            let x0 = center.x + side * bodyW * 0.20
            let x1 = center.x + side * spread

            var leg = Path()
            leg.move(to: CGPoint(x: x0, y: hipY))
            leg.addLine(to: CGPoint(x: x1, y: footY))
            // The foot is a kink in the same line, not an object. Outward, so the stance
            // reads as planted rather than pigeon-toed.
            leg.addLine(to: CGPoint(x: x1 + side * radius * 0.13, y: footY - radius * 0.012))
            strokeLimb(&context, leg, palette, width)
        }
    }

    private func drawArms(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette, time: TimeInterval
    ) {
        let sway = CGFloat(sin(time * 0.7)) * 0.03
        let width = limbWidth(radius)

        for side in [-1.0, 1.0] as [CGFloat] {
            let drop = side < 0 ? p.armLeft : p.armRight
            let shoulder = CGPoint(x: center.x + side * bodyW * 0.74, y: center.y + bodyH * 0.42)
            // `abs` on the horizontal terms: an arm is foreshortened whether it is raised
            // or lowered, and it keeps the widest reach at drop zero, which is the number
            // `Reach.armSpan` is derived from.
            let elbow = CGPoint(
                x: center.x + side * bodyW * (1.02 - abs(drop) * 0.07),
                y: shoulder.y + radius * (0.02 + drop * 0.18)
            )
            let wrist = CGPoint(
                x: center.x + side * bodyW * (1.18 - abs(drop) * 0.13),
                y: shoulder.y + radius * (0.16 + drop * 0.44 + sway)
            )

            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: elbow)
            arm.addLine(to: wrist)
            strokeLimb(&context, arm, palette, width)
        }
    }

    // MARK: Body

    /// How far the silhouette reaches at one angle, as a multiple of the body radii.
    ///
    /// Factored out of `bodyPath` so anything that has to follow the outline gets the
    /// real one: a highlight or an edge drawn on a plain ellipse while the body is lumpy
    /// separates from the contour and reads as a halo bolted on afterwards.
    private func lumpFactor(_ angle: Double) -> CGFloat {
        // Amplitude matters more than count, and it is amplitude *per degree of arc* that
        // decides whether a bump is a lobe or a cusp. Harmonic 6 at 0.072 swings the
        // radius 15% across 60 degrees and produced a five-pointed star. Harmonic 8 at
        // 0.048 swings 10% across 45 — the same lumpiness, curved instead of pointed.
        let lumps = 1
            + 0.048 * sin(angle * 8 + 0.9)
            + 0.018 * sin(angle * 13 - 0.4)

        // Crown dip: the longitudinal fissure pulls the top centre down. Narrow, so it
        // reads as a cleft rather than a flat top.
        let fromTop = abs(atan2(sin(angle + .pi / 2), cos(angle + .pi / 2)))
        let dip = 1 - 0.105 * exp(-pow(fromTop / 0.30, 2))
        return CGFloat(lumps * dip)
    }

    private func bodyPoint(
        _ angle: Double, center c: CGPoint, bodyW w: CGFloat, bodyH h: CGFloat
    ) -> CGPoint {
        let k = lumpFactor(angle)
        return CGPoint(x: c.x + w * k * CGFloat(cos(angle)), y: c.y + h * k * CGFloat(sin(angle)))
    }

    /// The silhouette, sampled rather than drawn with four beziers, because a brain's
    /// outline is *lumpy* — the folds reach the edge and push it out.
    private func bodyPath(center c: CGPoint, bodyW w: CGFloat, bodyH h: CGFloat) -> Path {
        var path = Path()
        let steps = 120
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi - .pi / 2
            let point = bodyPoint(angle, center: c, bodyW: w, bodyH: h)
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
        let span = max(bodyW, bodyH)
        let lightPoint = CGPoint(
            x: center.x + Light.dx * bodyW * 0.52,
            y: center.y + Light.dy * bodyH * 0.52
        )

        // Drips first, so the body is painted over the top of them and the seam where a
        // drip leaves the head never shows. Drawn afterwards, every one of them would
        // carry a contour line straight across its shoulder.
        if p.motifs.contains(.drip) {
            drawDrips(&context, center: center, bodyW: bodyW, bodyH: bodyH,
                      radius: radius, palette: palette)
        }

        context.fill(silhouette, with: .color(palette.base))

        context.drawLayer { layer in
            layer.clip(to: silhouette)

            // Key light and ambient occlusion: two radial gradients sharing one centre,
            // which is what makes the body a sphere before a single fold is drawn. Both
            // fade to a transparent version of *their own* colour rather than to nothing,
            // because a stop that fades toward an unrelated hue leaves a grey halo where
            // the two meet.
            layer.fill(silhouette, with: .radialGradient(
                Gradient(stops: [
                    .init(color: palette.lit.opacity(0.26 + 0.54 * Double(p.sheen)), location: 0),
                    .init(color: palette.lit.opacity(0), location: 1)
                ]),
                center: lightPoint, startRadius: 0, endRadius: span * 1.02
            ))
            layer.fill(silhouette, with: .radialGradient(
                Gradient(stops: [
                    .init(color: palette.deep.opacity(0), location: 0.34),
                    .init(color: palette.deep.opacity(0.30), location: 0.76),
                    .init(color: palette.deep.opacity(0.78), location: 1)
                ]),
                center: lightPoint, startRadius: 0, endRadius: span * 1.62
            ))

            // Bounce off the floor, in the floor's own colour. A warm body picking up the
            // cool lavender it stands on is what puts it *in* the room rather than on top
            // of a picture of one.
            layer.fill(silhouette, with: .radialGradient(
                Gradient(stops: [
                    .init(color: palette.bounce.opacity(0.14 + 0.16 * Double(p.sheen)), location: 0),
                    .init(color: palette.bounce.opacity(0), location: 1)
                ]),
                center: CGPoint(x: center.x + bodyW * 0.12, y: center.y + bodyH * 0.92),
                startRadius: 0, endRadius: bodyW * 0.95
            ))

            if detail {
                drawGyri(&layer, center: center, bodyW: bodyW, bodyH: bodyH,
                         radius: radius, palette: palette, lightPoint: lightPoint, span: span)
                if p.motifs.contains(.crack) {
                    drawCracks(&layer, center: center, bodyW: bodyW, bodyH: bodyH, palette: palette)
                }
                drawSpecular(&layer, lightPoint: lightPoint, bodyW: bodyW, bodyH: bodyH,
                             radius: radius, palette: palette)
            }
        }

        // Thin, now that the form does the describing. A heavy contour on a modelled body
        // reads as a sticker cut out of a render.
        context.stroke(
            silhouette, with: .color(palette.ink),
            style: StrokeStyle(lineWidth: max(radius * 0.048, 1.2), lineJoin: .round)
        )
    }

    /// One soft highlight where the light hits, and one small sharp one inside it.
    ///
    /// The soft one says the surface is curved; the sharp one says it is wet. `gloss`
    /// tightens the sharp one and `sheen` carries them both — which is the difference
    /// between firm tissue and a matte slumped dome, and it costs one blurred ellipse.
    private func drawSpecular(
        _ context: inout GraphicsContext, lightPoint: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette
    ) {
        guard p.sheen > 0.10 else { return }

        let w = bodyW * (0.46 - 0.16 * p.gloss)
        let h = bodyH * (0.30 - 0.11 * p.gloss)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * (0.16 - 0.07 * p.gloss)))
            layer.fill(
                Path(ellipseIn: CGRect(x: lightPoint.x - w / 2, y: lightPoint.y - h / 2,
                                       width: w, height: h)),
                with: .color(palette.shine.opacity(0.16 + 0.30 * Double(p.sheen)))
            )
        }

        guard p.gloss > 0.30 else { return }
        let cw = bodyW * 0.13 * p.gloss
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.022))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: lightPoint.x - cw / 2 + bodyW * 0.04,
                    y: lightPoint.y - cw * 0.34 - bodyH * 0.05,
                    width: cw, height: cw * 0.68
                )),
                with: .color(palette.shine.opacity(0.40 + 0.42 * Double(p.gloss)))
            )
        }
    }

    /// Deterministic pseudo-random. The same fold pattern every frame and every launch —
    /// a creature whose brain rearranged itself between frames would read as noise.
    private func rnd(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 127.1 + 311.7) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    /// The gyri, as ridges rather than as lines.
    ///
    /// This is the piece that separates a modelled creature from a drawn one. The flat
    /// version stroked one thin line per fold: a *boundary*. A real gyrus is a raised
    /// worm, and what makes it read as raised is not the line — it is the groove the
    /// ridge casts into the sulcus beside it. So each fold is four strokes on the same
    /// curve, offset along the one light vector:
    ///
    /// 1. the **groove**, wide and dark, pushed away from the light — the shadow the ridge
    ///    drops into the fold below it
    /// 2. the **body** of the ridge, barely lighter than the surface it sits on
    /// 3. the **crest**, thin and lit, pushed toward the light
    /// 4. a **specular pop**, only on the ridges near the light and only when the stage is
    ///    glossy enough to have one
    ///
    /// Step 4 is why the highlights cluster on the upper left instead of being sprinkled
    /// evenly, and sprinkled evenly is exactly what glitter looks like.
    ///
    /// `turgor` scales every offset. At `crisp` the folds stand proud and the sulci are
    /// deep; at `mush` they are smeared almost flat — which is the smooth-brain reading
    /// the whole ladder is built on, now expressed in the surface and not only in the
    /// count.
    private func drawGyri(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette,
        lightPoint: CGPoint, span: CGFloat
    ) {
        // Keep out of the face — but only out of the face. The first attempt used an
        // ellipse 0.95 radius wide and a full radius tall, which covered 94% of the body
        // and left three fold lines on the entire creature: a bald yellow field with
        // glasses on it. This is the box the glasses and mouth actually occupy, so the
        // folds keep the crown above the brows and the flanks outside the frames — which
        // is also where a real brain shows them.
        let eyeY = center.y + bodyH * 0.16
        let faceHalfW = bodyW * 0.285 + radius * 0.42
        let faceTop = eyeY - radius * (0.42 + 0.26)
        func clearsFace(_ point: CGPoint) -> Bool {
            abs(point.x - center.x) > faceHalfW || point.y < faceTop
        }

        let w = max(bodyW * 0.052, 1.4)
        let lift = w * p.turgor

        for side in [-1.0, 1.0] as [CGFloat] {
            for ring in 0..<p.foldRings {
                let count = p.foldsPerRing
                for index in 0..<count {
                    let seed = ring * 17 + index * 5 + (side > 0 ? 101 : 3)
                    let j1 = rnd(seed) - 0.5
                    let j2 = rnd(seed + 41) - 0.5

                    // Polar position inside the hemisphere. `radial` 0 is the fissure,
                    // 1 the outer edge; `arc` sweeps from crown to base.
                    let radial = 0.30 + CGFloat(ring) * (0.62 / CGFloat(max(p.foldRings, 1))) + j1 * 0.07
                    let arc = (CGFloat(index) + 0.5) / CGFloat(max(count, 1)) * 1.9 - 0.42 + j2 * 0.12

                    let px = center.x + side * bodyW * radial * CGFloat(cos(Double(arc) - 0.35))
                    let py = center.y - bodyH * 0.74 + bodyH * 1.86 * arc / 1.9 + bodyH * j2 * 0.06

                    guard clearsFace(CGPoint(x: px, y: py)) else { continue }

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

                    func ridge(_ ox: CGFloat, _ oy: CGFloat) -> Path {
                        var path = Path()
                        path.move(to: CGPoint(x: ax + ox, y: ay + oy))
                        path.addQuadCurve(to: CGPoint(x: bx + ox, y: by + oy),
                                          control: CGPoint(x: cxp + ox, y: cyp + oy))
                        return path
                    }
                    func cap(_ width: CGFloat) -> StrokeStyle {
                        StrokeStyle(lineWidth: width, lineCap: .round)
                    }

                    // How close this fold is to the light, 0...1. Drives the crest and
                    // gates the specular pop, which is what clusters the highlights.
                    let dx = px - lightPoint.x, dy = py - lightPoint.y
                    let distance = sqrt(dx * dx + dy * dy)
                    let fall = max(0, min(1, 1 - distance / (span * 1.15)))

                    context.stroke(
                        ridge(Light.awayX * lift * 0.62, Light.awayY * lift * 0.62),
                        with: .color(palette.deep.opacity(0.52 + 0.34 * Double(p.turgor))),
                        style: cap(w * 1.55)
                    )
                    context.stroke(ridge(0, 0), with: .color(palette.gyrus), style: cap(w * 1.10))
                    context.stroke(
                        ridge(Light.dx * lift * 0.34, Light.dy * lift * 0.34),
                        with: .color(palette.lit.opacity(0.30 + 0.55 * Double(fall) * Double(p.sheen))),
                        style: cap(w * 0.42)
                    )

                    if fall > 0.44 && p.gloss > 0.30 {
                        let pop = (Double(fall) - 0.44) / 0.56
                        context.stroke(
                            ridge(Light.dx * lift * 0.44, Light.dy * lift * 0.44),
                            with: .color(palette.shine.opacity(pop * Double(p.gloss) * 0.72)),
                            style: cap(w * 0.20)
                        )
                    }
                }
            }
        }

        // Longitudinal fissure: the one valley that splits the two halves. Drawn as a
        // groove with a lit lip on the side facing the light — the same treatment as a
        // gyrus, because it is the deepest fold on the object and drawing it as a plain
        // line would flatten the crown everything else just built.
        var fissure = Path()
        fissure.move(to: CGPoint(x: center.x, y: center.y - bodyH * 1.02))
        fissure.addCurve(
            to: CGPoint(x: center.x, y: center.y - bodyH * 0.34),
            control1: CGPoint(x: center.x + bodyW * 0.05, y: center.y - bodyH * 0.80),
            control2: CGPoint(x: center.x - bodyW * 0.05, y: center.y - bodyH * 0.52)
        )
        context.stroke(
            fissure, with: .color(palette.deep),
            style: StrokeStyle(lineWidth: w * 1.30, lineCap: .round)
        )
        context.drawLayer { layer in
            layer.translateBy(x: Light.dx * lift * 0.85, y: Light.dy * lift * 0.85)
            layer.stroke(
                fissure, with: .color(palette.lit.opacity(0.34 + 0.30 * Double(p.sheen))),
                style: StrokeStyle(lineWidth: w * 0.44, lineCap: .round)
            )
        }
    }

    // MARK: Motifs

    /// The body going. Three teardrops hanging off the lower contour, each starting well
    /// inside the silhouette so the body can be painted over their shoulders.
    private func drawDrips(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette
    ) {
        let yTop = center.y + bodyH * 0.70
        let edge = StrokeStyle(lineWidth: max(radius * 0.048, 1.2), lineJoin: .round)

        // The first version read as legs — three straight shapes hanging off the bottom
        // at roughly the length and weight of the real ones, so the creature appeared to
        // have five. What separates a drip from a limb is not where it is, it is the
        // *profile*: narrow where it leaves the body, swelling into a bead at the tip,
        // and short. A limb is even-width and long.
        for (offset, length, width) in [
            (CGFloat(-0.40), CGFloat(0.30), CGFloat(0.15)),
            (CGFloat(0.02), CGFloat(0.20), CGFloat(0.11)),
            (CGFloat(0.42), CGFloat(0.26), CGFloat(0.13))
        ] {
            let x = center.x + bodyW * offset
            let neck = radius * width * 0.42
            let bead = radius * width
            let len = radius * length

            var drip = Path()
            drip.move(to: CGPoint(x: x - neck, y: yTop))
            drip.addQuadCurve(
                to: CGPoint(x: x - bead, y: yTop + len),
                control: CGPoint(x: x - neck * 0.90, y: yTop + len * 0.70)
            )
            drip.addQuadCurve(
                to: CGPoint(x: x + bead, y: yTop + len),
                control: CGPoint(x: x, y: yTop + len + bead * 1.70)
            )
            drip.addQuadCurve(
                to: CGPoint(x: x + neck, y: yTop),
                control: CGPoint(x: x + neck * 0.90, y: yTop + len * 0.70)
            )
            drip.closeSubpath()

            // Modelled like everything else: shaded across the bead, with a highlight on
            // the light side. A drip is wet by definition, so it keeps its glint even at
            // `mush`, where the body itself has lost its own.
            context.fill(drip, with: .linearGradient(
                Gradient(colors: [palette.gyrus, palette.shade]),
                startPoint: CGPoint(x: x + Light.dx * bead, y: yTop + Light.dy * bead),
                endPoint: CGPoint(x: x + Light.awayX * bead * 1.6, y: yTop + len + bead)
            ))
            context.stroke(drip, with: .color(palette.ink), style: edge)
            context.fill(
                Path(ellipseIn: CGRect(x: x - bead * 0.62, y: yTop + len - bead * 0.52,
                                       width: bead * 0.44, height: bead * 0.32)),
                with: .color(palette.shine.opacity(0.55))
            )
        }

        // One droplet already fallen, detached. This is the cue that does the most work:
        // a shape hanging off a body is ambiguous, and a shape in mid-air under it is not.
        let fallen = CGRect(
            x: center.x - bodyW * 0.40 - radius * 0.062,
            y: yTop + radius * 0.50,
            width: radius * 0.124, height: radius * 0.155
        )
        context.fill(Path(ellipseIn: fallen), with: .linearGradient(
            Gradient(colors: [palette.gyrus, palette.shade]),
            startPoint: CGPoint(x: fallen.minX, y: fallen.minY),
            endPoint: CGPoint(x: fallen.maxX, y: fallen.maxY)
        ))
        context.stroke(Path(ellipseIn: fallen), with: .color(palette.ink), style: edge)
    }

    /// Fissures that are not gyri. A fold curves and closes; a crack veers and stops, and
    /// that difference is the whole point — one is structure, the other is damage.
    ///
    /// Two strokes: the dark split, and a lit lip along its upper edge. The lip is what
    /// makes it a crack *in* a surface rather than a line drawn *on* one — the same trick
    /// as the gyri, which keeps the damage in the same material as the body.
    private func drawCracks(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, palette: Palette
    ) {
        let width = max(bodyW * 0.036, 1.2)
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .miter)

        // They run *outward*, toward the rim. The first version started them near the
        // midline and walked down and to the right, straight into the face — where the
        // eyes and glasses are painted over the top of them, so the stage that needed
        // them most had none you could see.
        let origins: [(CGFloat, CGFloat)] = [(-0.34, -0.78), (0.16, -0.90), (0.46, -0.58)]

        for (index, origin) in origins.enumerated() {
            let seed = [7, 23, 51][index]
            let away: CGFloat = origin.0 < 0 ? -1 : 1
            var point = CGPoint(x: center.x + bodyW * origin.0, y: center.y + bodyH * origin.1)

            var crack = Path()
            crack.move(to: point)
            // Four short segments, each veering. A fold curves and closes; a crack veers
            // and stops, and the veering is the whole difference.
            for step in 1...4 {
                let jitter = rnd(seed + step * 13) - 0.5
                point = CGPoint(
                    x: point.x + bodyW * away * (0.13 + jitter * 0.14),
                    y: point.y + bodyH * (0.11 + jitter * 0.12)
                )
                crack.addLine(to: point)
            }
            context.drawLayer { layer in
                layer.translateBy(x: Light.dx * width * 0.55, y: Light.dy * width * 0.55)
                layer.stroke(crack, with: .color(palette.lit.opacity(0.30)),
                             style: StrokeStyle(lineWidth: width * 0.62, lineCap: .round))
            }
            context.stroke(crack, with: .color(palette.deep), style: style)
        }
    }

    /// Four-pointed stars, waisted so they read as a sparkle and not as a plus sign.
    /// Healing only — this is the one motif that says the number went up.
    private func drawSparkles(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, time: TimeInterval
    ) {
        // Kept inside 1.10 x bodyH vertically so the fit in `Reach` still holds: the crown
        // already sits at 1.09, and a sparkle above that would be clipped off the canvas.
        let places: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (-1.16, -0.52, 0.135, 0.0),
            (1.08, -0.78, 0.100, 1.7),
            (0.50, -1.06, 0.075, 3.1)
        ]

        for (mx, my, size, phase) in places {
            // A twinkle, not a spin: scale only, slow, out of phase with its neighbours.
            // At `time == 0` — every widget, every static render — it sits at full size.
            let twinkle: CGFloat = time > 0
                ? 0.72 + 0.28 * CGFloat(sin(time * 1.8 + phase))
                : 1
            let r = radius * size * twinkle
            let sx = center.x + bodyW * mx
            let sy = center.y + bodyH * my

            // A bloom under each star. Without it a hard white shape on a dark ground
            // reads as a cut-out; with it, it reads as something emitting.
            // Green, not white. A white star on a near-white viewport is an invisible
            // star, and the motif that says "the number went up" was the one thing that
            // could not afford to disappear in the flip to a light theme. `good` is the
            // same green the progress bar uses, so the reading is already learned.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: r * 0.55))
                layer.fill(
                    Path(ellipseIn: CGRect(x: sx - r * 1.15, y: sy - r * 1.15,
                                           width: r * 2.3, height: r * 2.3)),
                    with: .color(Token.Color.good.opacity(0.30))
                )
            }

            let arms: [(CGFloat, CGFloat)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
            var star = Path()
            star.move(to: CGPoint(x: sx, y: sy - r))
            for index in 0..<4 {
                let here = arms[index]
                let next = arms[(index + 1) % 4]
                star.addQuadCurve(
                    to: CGPoint(x: sx + next.0 * r, y: sy + next.1 * r),
                    control: CGPoint(
                        x: sx + (here.0 + next.0) * r * 0.15,
                        y: sy + (here.1 + next.1) * r * 0.15
                    )
                )
            }
            star.closeSubpath()
            context.fill(star, with: .color(Token.Color.good))
        }
    }

    /// One bead at the temple. The oldest shorthand in cartooning for "this is a lot".
    private func drawSweat(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat
    ) {
        let x = center.x + bodyW * 0.70
        let y = center.y - bodyH * 0.46
        let w = radius * 0.10
        let h = radius * 0.20

        var bead = Path()
        bead.move(to: CGPoint(x: x, y: y - h))
        bead.addQuadCurve(to: CGPoint(x: x + w, y: y + h * 0.25),
                          control: CGPoint(x: x + w * 0.55, y: y - h * 0.25))
        bead.addQuadCurve(to: CGPoint(x: x - w, y: y + h * 0.25),
                          control: CGPoint(x: x, y: y + h * 1.15))
        bead.addQuadCurve(to: CGPoint(x: x, y: y - h),
                          control: CGPoint(x: x - w * 0.55, y: y - h * 0.25))
        bead.closeSubpath()

        // Blue, because it is the one colour in the system that is not the creature and
        // not a status: it reads as water rather than as a reading. Lit from the same
        // corner as everything else, and darker at the bottom where the bead is thickest.
        context.fill(bead, with: .linearGradient(
            Gradient(colors: [Token.Color.eyeIris.mix(with: Token.Color.specular, by: 0.45),
                              Token.Color.eyeIrisDeep]),
            startPoint: CGPoint(x: x + Light.dx * w, y: y + Light.dy * h),
            endPoint: CGPoint(x: x + Light.awayX * w, y: y + h)
        ))
        context.fill(
            Path(ellipseIn: CGRect(x: x - w * 0.50, y: y - h * 0.05,
                                   width: w * 0.40, height: w * 0.40)),
            with: .color(Token.Color.specular.opacity(0.90))
        )
    }

    // MARK: Face

    private func drawFace(
        _ context: inout GraphicsContext, center: CGPoint,
        bodyW: CGFloat, bodyH: CGFloat, radius: CGFloat, palette: Palette,
        time: TimeInterval, detail: Bool
    ) {
        // Low in the body and close together, which is the proportion that makes a face
        // read as small-and-young rather than as a face on a ball. The eye grew from
        // 0.160 to 0.195 and the lens had to grow with it: at the old 0.345 the wide-eyed
        // `buzzed` sclera pushes past the rim and the frames read as goggles.
        let eyeY = center.y + bodyH * 0.16
        let eyeX = bodyW * 0.285
        let lensR = radius * 0.42
        let rx = radius * 0.195
        let ry = rx * 1.04 * p.open

        // Blink. Cheap, and most of what makes something read as alive.
        //
        // Guarded on `time > 0` because a static render passes zero, and zero sits inside
        // the blink window — which had every widget and Dynamic Island drawing the
        // creature with its eyes shut.
        // 90ms shut, which is a real blink. The window used to be 120ms against
        // `buzzed`'s 1.1-second interval — an 11% duty cycle, so about one screenshot in
        // nine caught the creature with its eyes closed and read as a bug.
        let cycle = time.truncatingRemainder(dividingBy: p.blinkInterval)
        let blink: CGFloat = (time > 0 && cycle < 0.09) ? 0 : 1

        // The sockets, before anything else on the face: two soft dark pools that push the
        // eyes back into the head. A face whose features all sit on the same plane is the
        // flattest part of any modelled character, and this is the cheapest fix — one
        // gradient per eye.
        if detail {
            for side in [-1.0, 1.0] as [CGFloat] {
                let ex = center.x + side * eyeX
                let socket = lensR * 1.22
                context.fill(
                    Path(ellipseIn: CGRect(x: ex - socket, y: eyeY - socket * 0.94,
                                           width: socket * 2, height: socket * 1.88)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: palette.deep.opacity(0.34), location: 0),
                            .init(color: palette.deep.opacity(0.16), location: 0.62),
                            .init(color: palette.deep.opacity(0), location: 1)
                        ]),
                        center: CGPoint(x: ex, y: eyeY), startRadius: 0, endRadius: socket
                    )
                )
            }
        }

        drawBlush(&context, center: center, eyeX: eyeX, eyeY: eyeY,
                  lensR: lensR, radius: radius, palette: palette)

        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX
            drawEye(&context, ex: ex, eyeY: eyeY, rx: rx, ry: ry, blink: blink,
                    side: side, time: time, palette: palette, detail: detail)
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
        let w = radius * 0.34
        let h = radius * 0.20
        for side in [-1.0, 1.0] as [CGFloat] {
            let cxp = center.x + side * (eyeX + radius * 0.12)
            let cyp = eyeY + lensR * 1.05
            // Soft-edged, unlike the flat version's hard ellipse. Blush is subsurface — it
            // has no boundary, and a hard edge on it reads as two painted circles.
            context.fill(
                Path(ellipseIn: CGRect(x: cxp - w / 2, y: cyp - h / 2, width: w, height: h)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: palette.blush.opacity(Double(0.50 + 0.28 * p.sheen)), location: 0),
                        .init(color: palette.blush.opacity(0), location: 1)
                    ]),
                    center: CGPoint(x: cxp, y: cyp), startRadius: 0, endRadius: w / 2
                )
            )
        }
    }

    private func drawEye(
        _ context: inout GraphicsContext, ex: CGFloat, eyeY: CGFloat,
        rx: CGFloat, ry: CGFloat, blink: CGFloat, side: CGFloat,
        time: TimeInterval, palette: Palette, detail: Bool
    ) {
        guard blink > 0.5 else {
            // Shut. One ink curve, the way a drawing closes an eye — a 0.08-scale white
            // ellipse left a pale sliver behind the lens and read as an empty frame.
            var lid = Path()
            lid.move(to: CGPoint(x: ex - rx * 0.92, y: eyeY))
            lid.addQuadCurve(
                to: CGPoint(x: ex + rx * 0.92, y: eyeY),
                control: CGPoint(x: ex, y: eyeY + rx * 0.62)
            )
            context.stroke(
                lid, with: .color(palette.ink),
                style: StrokeStyle(lineWidth: max(rx * 0.30, 1.2), lineCap: .round)
            )
            return
        }

        let sclera = CGRect(x: ex - rx, y: eyeY - ry, width: rx * 2, height: ry * 2)
        // An eyeball is a sphere, not a white disc: brightest where the light hits it, and
        // picking up the body's own shade around the rim.
        context.fill(Path(ellipseIn: sclera), with: .radialGradient(
            Gradient(colors: [palette.shine, palette.shine.mix(with: palette.shade, by: 0.30)]),
            center: CGPoint(x: ex + Light.dx * rx * 0.42, y: eyeY + Light.dy * ry * 0.42),
            startRadius: 0, endRadius: rx * 1.5
        ))

        // Buzzed cannot hold a gaze.
        let gaze = p.jitter > 0 ? CGFloat(sin(time * 5.3 + Double(side))) * rx * 0.14 : 0
        let irisR = rx * 0.78
        let ix = ex + gaze
        let iy = eyeY + ry * 0.05

        // Hypnotised. A spiral where the pupil should be is the one drawing the whole
        // internet already reads as brainrot, and it costs sixty line segments. It turns
        // slowly, and slowly is the point — a fast spin would be a loading indicator.
        if p.motifs.contains(.spiral) {
            var spiral = Path()
            let steps = 60
            let spin = time > 0 ? time * 0.7 : 0
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let angle = progress * 2.7 * 2 * .pi + spin
                let r = rx * 0.94 * CGFloat(progress)
                let point = CGPoint(
                    x: ix + r * CGFloat(cos(angle)),
                    y: iy + r * CGFloat(sin(angle))
                )
                if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
            }
            context.stroke(
                spiral, with: .color(Token.Color.eyePupil),
                style: StrokeStyle(lineWidth: max(rx * 0.20, 1), lineCap: .round, lineJoin: .round)
            )
        } else {
            // The iris is a dish, not a disc: dark at the limbus, bright at the floor, so
            // the pupil sits *in* something. The ring at the edge is what a real limbal
            // ring does, and it is most of why an eye reads as an eye at small sizes.
            let irisRect = CGRect(x: ix - irisR, y: iy - irisR, width: irisR * 2, height: irisR * 2)
            context.fill(Path(ellipseIn: irisRect), with: .radialGradient(
                Gradient(colors: [
                    Token.Color.eyeIris.mix(with: Token.Color.specular, by: 0.30),
                    Token.Color.eyeIris,
                    Token.Color.eyeIrisDeep
                ]),
                center: CGPoint(x: ix + Light.awayX * irisR * 0.25,
                                y: iy + Light.awayY * irisR * 0.25),
                startRadius: 0, endRadius: irisR * 1.35
            ))
            context.stroke(
                Path(ellipseIn: irisRect), with: .color(Token.Color.eyeIrisDeep.opacity(0.85)),
                style: StrokeStyle(lineWidth: max(irisR * 0.16, 0.6))
            )

            let pupilR = irisR * (0.94 - p.pupil * 0.5)
            context.fill(
                Path(ellipseIn: CGRect(x: ix - pupilR, y: iy - pupilR,
                                       width: pupilR * 2, height: pupilR * 2)),
                with: .color(Token.Color.eyePupil)
            )

            // Light that went through the iris and came back out the other side. It sits
            // opposite the catchlight, always, and it is the single detail that most
            // separates a modelled eye from two circles.
            if detail {
                let bounce = irisR * 0.52
                context.fill(
                    Path(ellipseIn: CGRect(x: ix + Light.awayX * irisR * 0.34 - bounce / 2,
                                           y: iy + Light.awayY * irisR * 0.30 - bounce / 2,
                                           width: bounce, height: bounce * 0.7)),
                    with: .color(Token.Color.eyeIris.mix(with: Token.Color.specular, by: 0.55)
                        .opacity(0.42))
                )
            }

            let glintR = irisR * 0.30
            context.fill(
                Path(ellipseIn: CGRect(x: ix + Light.dx * irisR * 0.42 - glintR,
                                       y: iy + Light.dy * irisR * 0.42 - glintR,
                                       width: glintR * 2, height: glintR * 2)),
                with: .color(palette.shine)
            )
            if detail {
                let small = glintR * 0.42
                context.fill(
                    Path(ellipseIn: CGRect(x: ix + Light.awayX * irisR * 0.42,
                                           y: iy + Light.awayY * irisR * 0.38,
                                           width: small * 2, height: small * 2)),
                    with: .color(palette.shine.opacity(0.60))
                )
            }
        }

        // The brow ridge shading the top of the eyeball. Every eye has this, and it is
        // invisible until it is missing — at which point the eye reads as a sticker.
        if detail {
            context.drawLayer { layer in
                layer.clip(to: Path(ellipseIn: sclera))
                layer.fill(Path(ellipseIn: CGRect(
                    x: sclera.minX - rx * 0.2, y: sclera.minY - ry * 1.30,
                    width: sclera.width + rx * 0.4, height: ry * 1.86
                )), with: .color(palette.deep.opacity(0.22)))
            }
        }

        // Heavy lid, in the body colour, so it reads as the brain closing over the eye
        // rather than a grey bar laid on top. Its own lower edge is darker, because a lid
        // has thickness.
        if p.lid > 0.01 {
            context.drawLayer { layer in
                layer.clip(to: Path(ellipseIn: sclera.insetBy(dx: -1, dy: -1)))
                let depth = (ry * 2 + 4) * p.lid * 0.62
                let lidRect = CGRect(x: sclera.minX - 2, y: sclera.minY - 2,
                                     width: sclera.width + 4, height: depth)
                layer.fill(Path(lidRect), with: .linearGradient(
                    Gradient(colors: [palette.shade, palette.base]),
                    startPoint: CGPoint(x: lidRect.minX, y: lidRect.minY),
                    endPoint: CGPoint(x: lidRect.minX, y: lidRect.maxY)
                ))
                layer.fill(
                    Path(CGRect(x: lidRect.minX, y: lidRect.maxY - max(ry * 0.16, 0.7),
                                width: lidRect.width, height: max(ry * 0.16, 0.7))),
                    with: .color(palette.ink.opacity(0.55))
                )
            }
        }
    }

    /// Round wire frames — and now an actual object rather than two circles on a face.
    ///
    /// Four things make it read as one: the frame's **shadow** on the brain behind it, a
    /// faint **glass tint** filling the lens, a **lit upper edge** on the wire, and two
    /// **streaks** across the glass. The temple's hook is the fifth and the oldest:
    /// without it the arm ends in mid-air, and the whole thing goes back to being a
    /// drawing.
    private func drawGlasses(
        _ context: inout GraphicsContext, center: CGPoint, eyeX: CGFloat, eyeY: CGFloat,
        lensR: CGFloat, radius: CGFloat, palette: Palette, detail: Bool
    ) {
        let wire = max(radius * 0.050, 1.2)
        let style = StrokeStyle(lineWidth: wire, lineCap: .round, lineJoin: .round)

        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = center.x + side * eyeX
            let lens = CGRect(x: ex - lensR, y: eyeY - lensR, width: lensR * 2, height: lensR * 2)
            let ring = Path(ellipseIn: lens)

            if detail {
                // Cast by the frame onto the face, away from the light like everything
                // else. This is the one element that puts the glasses *in front of* the
                // brain instead of on the same plane as it.
                context.drawLayer { layer in
                    layer.translateBy(x: Light.awayX * wire * 1.9, y: Light.awayY * wire * 1.9)
                    layer.addFilter(.blur(radius: wire * 0.55))
                    layer.stroke(ring, with: .color(palette.deep.opacity(0.42)),
                                 style: StrokeStyle(lineWidth: wire * 1.25))
                }
                // Glass. Barely there — a lens you can read the eye through, tinted and
                // brighter at the top where it faces the sky.
                context.fill(ring, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: palette.glass.opacity(0.30), location: 0),
                        .init(color: palette.glass.opacity(0.05), location: 0.55),
                        .init(color: palette.glass.opacity(0.14), location: 1)
                    ]),
                    startPoint: CGPoint(x: lens.minX, y: lens.minY),
                    endPoint: CGPoint(x: lens.maxX, y: lens.maxY)
                ))
            }

            context.stroke(ring, with: .color(palette.ink), style: style)
            if detail {
                // Metal catches light on one edge only. The ring is stroked again, thin
                // and offset toward the light — the overlap is what reads as a bevel.
                context.drawLayer { layer in
                    layer.translateBy(x: Light.dx * wire * 0.26, y: Light.dy * wire * 0.26)
                    layer.stroke(ring, with: .color(palette.lit.opacity(0.55)),
                                 style: StrokeStyle(lineWidth: wire * 0.36))
                }

                // Two parallel streaks, the long one thick. One streak reads as a scratch;
                // two parallel ones read as glass, everywhere, in every medium.
                for (start, end, weight) in [
                    (CGFloat(0.62), CGFloat(0.16), CGFloat(1.0)),
                    (CGFloat(0.30), CGFloat(-0.12), CGFloat(0.55))
                ] {
                    var streak = Path()
                    streak.move(to: CGPoint(x: ex - lensR * start, y: eyeY + lensR * (start - 0.42)))
                    streak.addLine(to: CGPoint(x: ex - lensR * end, y: eyeY + lensR * (end - 0.42)))
                    context.stroke(
                        streak, with: .color(Token.Color.specular.opacity(Double(weight) * 0.50)),
                        style: StrokeStyle(lineWidth: wire * weight * 0.95, lineCap: .round)
                    )
                }
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
            if detail {
                context.drawLayer { layer in
                    layer.translateBy(x: Light.dx * wire * 0.24, y: Light.dy * wire * 0.24)
                    layer.stroke(temple, with: .color(palette.lit.opacity(0.40)),
                                 style: StrokeStyle(lineWidth: wire * 0.32, lineCap: .round))
                }
            }
        }

        // Bridge, bowed upward between the two rings.
        var bridge = Path()
        bridge.move(to: CGPoint(x: center.x - eyeX + lensR * 0.94, y: eyeY - lensR * 0.20))
        bridge.addQuadCurve(
            to: CGPoint(x: center.x + eyeX - lensR * 0.94, y: eyeY - lensR * 0.20),
            control: CGPoint(x: center.x, y: eyeY - lensR * 0.62)
        )
        context.stroke(bridge, with: .color(palette.ink), style: style)
        if detail {
            context.drawLayer { layer in
                layer.translateBy(x: Light.dx * wire * 0.24, y: Light.dy * wire * 0.24)
                layer.stroke(bridge, with: .color(palette.lit.opacity(0.45)),
                             style: StrokeStyle(lineWidth: wire * 0.32, lineCap: .round))
            }
        }
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
                // A brow is a ridge in the surface, so it gets the same two-stroke
                // treatment as a gyrus: dark body, lit lip toward the light.
                layer.stroke(
                    brow, with: .color(palette.ink),
                    style: StrokeStyle(lineWidth: max(radius * 0.078, 1.4), lineCap: .round)
                )
                layer.translateBy(x: Light.dx * radius * 0.024, y: Light.dy * radius * 0.024)
                layer.stroke(
                    brow, with: .color(palette.lit.opacity(0.34)),
                    style: StrokeStyle(lineWidth: max(radius * 0.026, 0.8), lineCap: .round)
                )
            }
        }
    }

    /// Above 0.15 the mouth opens — a cavity with a tongue and one tooth. Below, it is a
    /// single stroked curve that turns down as the number falls.
    ///
    /// The open mouth is reserved for the good stages on purpose. An open smile is the
    /// loudest thing on the face, and a creature grinning through a bad day is the exact
    /// coach tone `brand.json` forbids.
    private func drawMouth(
        _ context: inout GraphicsContext, center: CGPoint, eyeY: CGFloat,
        radius: CGFloat, palette: Palette
    ) {
        let my = eyeY + radius * 0.58

        // A squiggle, once the number is genuinely bad. A downturned arc reads as sad,
        // which is a mood; a wavy line reads as unwell, which is a condition — and the
        // difference between those two is the difference this whole ladder is about.
        // `buzzed` stays on the plain frown at -0.18: it is tense, not sick.
        if p.mouth < -0.35 {
            let mw = radius * 0.18
            let amplitude = radius * 0.062
            let step = mw * 2 / 3

            var wave = Path()
            wave.move(to: CGPoint(x: center.x - mw, y: my))
            for segment in 0..<3 {
                let from = center.x - mw + step * CGFloat(segment)
                let to = from + step
                let direction: CGFloat = segment % 2 == 0 ? -1 : 1
                wave.addQuadCurve(
                    to: CGPoint(x: to, y: my),
                    control: CGPoint(x: (from + to) / 2, y: my + amplitude * direction)
                )
            }
            context.stroke(
                wave, with: .color(palette.ink),
                style: StrokeStyle(lineWidth: max(radius * 0.058, 1.2), lineCap: .round)
            )
            return
        }

        guard p.mouth > 0.15 else {
            let mw = radius * 0.16
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

        // Small. The face gained a lot of eye, and an open grin at the old width turned
        // the whole head into a mouth. A small mouth under big eyes is the proportion that
        // reads as a young creature rather than as a cartoon adult.
        let mw = radius * (0.13 + 0.07 * p.mouth)
        let depth = radius * (0.11 + 0.17 * p.mouth)

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

        // A cavity, so it gets depth: near-black at the throat, lifting to the ink colour
        // at the lips. A flat fill here is a hole cut in the face.
        context.fill(shape, with: .radialGradient(
            Gradient(colors: [palette.ink, palette.ink.mix(with: Token.Color.shadeAnchor, by: 0.55)]),
            center: CGPoint(x: center.x, y: my + depth * 0.55),
            startRadius: 0, endRadius: mw * 1.5
        ))

        context.drawLayer { layer in
            layer.clip(to: shape)
            // Tongue, resting on the lower lip, wet on top.
            let tongue = CGRect(
                x: center.x - mw * 0.62, y: my + depth * 0.44,
                width: mw * 1.24, height: depth * 1.5
            )
            layer.fill(Path(ellipseIn: tongue), with: .radialGradient(
                Gradient(colors: [palette.tongue.mix(with: Token.Color.specular, by: 0.22),
                                  palette.tongue]),
                center: CGPoint(x: tongue.midX + Light.dx * mw * 0.3,
                                y: tongue.midY + Light.dy * depth * 0.3),
                startRadius: 0, endRadius: mw
            ))
            // One tooth on the upper lip. Two would read as a grimace.
            let tooth = CGRect(
                x: center.x - mw * 0.34, y: my - depth * 0.10,
                width: mw * 0.62, height: depth * 0.34
            )
            layer.fill(Path(tooth), with: .color(Token.Color.specular))
            layer.fill(
                Path(CGRect(x: tooth.minX, y: tooth.maxY - depth * 0.08,
                            width: tooth.width, height: depth * 0.08)),
                with: .color(palette.shade.opacity(0.45))
            )
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
