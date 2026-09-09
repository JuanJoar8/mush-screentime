import Foundation
import Testing
@testable import MushKit

// The five stages are the product. These assert the thing brand.json states as a rule:
// a stage that is only distinguishable by its colour is wrong.
//
// None of this is testable by looking at a screenshot, which is the point. A screenshot
// tells you what one stage looks like; these tell you the five differ from each other in
// the ways the design says they should, and they keep telling you after someone nudges a
// number six months from now.

private let ladder: [BrainStage] = [.crisp, .foggy, .buzzed, .melting, .mush]

private func params(_ stage: BrainStage) -> CreatureParameters { .forStage(stage) }

@Test("Fold density falls the whole way down the ladder")
func foldDensityFallsWithHealth() {
    // A brain losing its convolutions is the metaphor the whole design leans on, so this
    // is the one axis that must be monotonic — a stage with more folds than a healthier
    // one would read as recovering while its number fell.
    let counts = ladder.map { params($0).foldsPerSide }
    for (index, count) in counts.enumerated().dropFirst() {
        #expect(
            count <= counts[index - 1],
            "\(ladder[index]) has \(count) folds, more than \(ladder[index - 1])'s \(counts[index - 1])"
        )
    }
    // And the ends have to be far apart, not merely ordered. Sixteen against two.
    #expect(counts.first! >= counts.last! * 4)
}

@Test("Motifs split the ladder into healing and rot, with nothing in both")
func motifsSplitTheLadder() {
    let healing: Motifs = [.sparkle]
    let rot: Motifs = [.drip, .crack]

    for stage in ladder {
        let motifs = params(stage).motifs
        #expect(
            !(motifs.intersects(healing) && motifs.intersects(rot)),
            "\(stage) carries both a healing and a rot motif"
        )
    }

    #expect(params(.crisp).motifs.contains(.sparkle), "the top of the ladder has no reward")
    #expect(params(.mush).motifs.contains(.drip))
    #expect(params(.melting).motifs.contains(.drip))
    // Buzzed is the hinge: overstimulated, not damaged. It gets neither side's motifs.
    #expect(!params(.buzzed).motifs.intersects(healing))
    #expect(!params(.buzzed).motifs.intersects(rot))
    #expect(params(.buzzed).motifs.contains(.spiral))
}

@Test("No stage gives both arms the same height")
func noStageIsSymmetric() {
    // Symmetry is the single thing that makes a drawn figure look switched off.
    for stage in ladder {
        let p = params(stage)
        #expect(p.armLeft != p.armRight, "\(stage) has both arms at \(p.armLeft)")
    }
}

@Test("No stage is another stage with the colour changed")
func noStageIsAColourSwap() {
    // brand.json forbids this in prose. Here it is as an exit code.
    //
    // Twelve of seventeen, measured against a real minimum of fifteen — the closest pair
    // is crisp and mush, which sit at opposite ends and still share two numbers (pupil
    // and jitter). Three of slack, so an honest tuning change does not trip it and a
    // stage collapsing into a recolour of its neighbour does.
    //
    // The threshold moved with the count. `turgor` and `gloss` differ across every pair,
    // so leaving it at ten would have quietly bought five more of slack — a test that
    // gets easier when the thing it guards gets bigger is not guarding anything.
    func signature(_ p: CreatureParameters) -> [Double] {
        [
            Double(p.browTilt), Double(p.browLift), Double(p.lid), Double(p.open),
            Double(p.sag), Double(p.spread), Double(p.sheen), Double(p.pupil),
            Double(p.mouth), Double(p.armLeft), Double(p.armRight), Double(p.jitter),
            Double(p.turgor), Double(p.gloss),
            p.blinkInterval, Double(p.foldsPerSide), Double(p.motifs.rawValue)
        ]
    }

    for (i, a) in ladder.enumerated() {
        for b in ladder.dropFirst(i + 1) {
            let left = signature(params(a))
            let right = signature(params(b))
            let differing = zip(left, right).filter { $0.0 != $0.1 }.count
            #expect(
                differing >= 12,
                "\(a) and \(b) differ in only \(differing) of \(left.count) parameters"
            )
        }
    }
}

@Test("Each stage lands in the mouth its condition calls for")
func mouthBucketsAreIntended() {
    // Three mouths, not a scale: open above 0.15, a plain arc between, a squiggle below
    // -0.35. A downturned arc is a mood; a wavy line is a condition.
    #expect(params(.crisp).mouth > 0.15, "crisp should be grinning")
    #expect(params(.foggy).mouth > 0.15, "foggy is still fine")
    #expect(params(.buzzed).mouth <= 0.15 && params(.buzzed).mouth >= -0.35,
            "buzzed is tense, not sick — a plain frown")
    #expect(params(.melting).mouth < -0.35, "melting should have the squiggle")
    #expect(params(.mush).mouth < -0.35, "mush should have the squiggle")
}

@Test("Only the agitated stage trembles, and it blinks like a person")
func onlyBuzzedIsJittery() {
    for stage in ladder where stage != .buzzed {
        #expect(params(stage).jitter == 0, "\(stage) should be still")
    }
    #expect(params(.buzzed).jitter > 0)

    // The blink window is a fixed 90ms, so the interval is the whole duty cycle. At 1.1
    // seconds buzzed was shut 11% of the time and roughly one screenshot in nine caught
    // it — including widget snapshots, where it simply looked broken.
    for stage in ladder {
        let duty = 0.09 / params(stage).blinkInterval
        #expect(duty < 0.06, "\(stage) blinks \(Int(duty * 100))% of the time")
    }
}

@Test("The surface carries the ladder, and three axes break it on purpose")
func materialAxesAreDeliberate() {
    // Turgor peaks at `buzzed`, and that peak is deliberate — resolved 2026-09-09, after
    // this test and the table it checks shipped in the same commit contradicting each
    // other and left CI red for a day.
    //
    // The reading that won: overstimulated is not soft. A wired brain is *tense* — the
    // folds stand harder than a foggy one's, which has already started to give. That is
    // the same fact `gloss` records one line down, and the two now agree instead of
    // saying opposite things about the same stage.
    //
    // So this asserts the **shape**, which is a tighter guard than the monotonicity it
    // replaces, not a looser one: nothing out-stands crisp, buzzed sits above foggy, and
    // the tail below buzzed still falls all the way down. A drift in any of the four
    // relationships fails, where "monotonic" only ever caught one of them.
    let turgor = ladder.map { params($0).turgor }
    #expect(params(.crisp).turgor > params(.foggy).turgor, "nothing stands prouder than crisp")
    #expect(params(.buzzed).turgor > params(.foggy).turgor,
            "buzzed must stand prouder than foggy — wired is tense, and that peak is the point")
    #expect(params(.melting).turgor < params(.foggy).turgor, "melting has given up more than foggy")
    #expect(params(.mush).turgor < params(.melting).turgor, "mush is the flattest thing here")
    #expect(turgor.first! >= turgor.last! * 3, "the ends are not far enough apart to read")

    // Gloss is deliberately *not* monotonic, and this is the assertion that says so out
    // loud. Buzzed sits one rung below foggy and is the wetter, shinier of the two,
    // because overstimulated is not dull — it is the most awake the creature ever looks
    // and the least well it is doing. If someone ever tidies this into a clean descent,
    // the five stages become five settings of one slider, and this fails and says why.
    #expect(params(.buzzed).gloss > params(.foggy).gloss,
            "buzzed must out-shine foggy — that non-monotonicity is the whole point")
    #expect(params(.crisp).gloss > params(.buzzed).gloss, "nothing out-shines crisp")
    #expect(params(.mush).gloss < 0.10, "mush must be matte")
}

@Test("Decay reads as decay, and health reads as more than the absence of it")
func rotAndVitalityAreSeparateReadings() {
    // Necrosis is monotonic, unlike gloss and film. Decay has one direction, and a stage
    // that was less rotten than a healthier one would say the creature had healed while
    // every other axis said it had not.
    let necrosis = ladder.map { params($0).necrosis }
    for (index, value) in necrosis.enumerated().dropFirst() {
        #expect(
            value >= necrosis[index - 1],
            "\(ladder[index]) is less rotten than \(ladder[index - 1])"
        )
    }
    #expect(params(.crisp).necrosis == 0, "healthy tissue is not partly dead")
    #expect(params(.mush).necrosis >= 0.9, "the bottom of the ladder has to be far gone")

    // Translucency is the superior half, and it has to be an axis of its own rather than
    // one over. A specular says the surface is wet; only transmission says there is
    // something alive behind the surface, which is why crisp cannot be reached by turning
    // gloss up.
    let translucency = ladder.map { params($0).translucency }
    for (index, value) in translucency.enumerated().dropFirst() {
        #expect(
            value <= translucency[index - 1],
            "\(ladder[index]) transmits more light than \(ladder[index - 1])"
        )
    }
    #expect(params(.mush).translucency == 0, "dead tissue does not transmit")
    #expect(params(.crisp).translucency >= params(.buzzed).translucency * 2,
            "the ends are not far enough apart to read as a different material")

    // Film dips at the bottom, and the dip is the point. Melting is actively liquefying
    // and is the greasiest the creature ever gets; mush has dried out past wet into dull.
    // Ramping film straight to the bottom would say decay only ever gets wetter, which is
    // the opposite of what happens, so tidying this into a clean ramp fails here.
    #expect(params(.melting).film > params(.mush).film,
            "melting must out-grease mush - decay stops being wet, and that dip is the point")
    #expect(params(.crisp).film == 0, "living tissue is glossy, never greasy")

    // The two wetnesses have to come apart somewhere, or film is just gloss spelled
    // differently. Melting is where: almost no specular, more film than any other stage.
    #expect(params(.melting).film > params(.melting).gloss * 3,
            "film and gloss must be separable readings, not one axis under two names")
}

private extension Motifs {
    func intersects(_ other: Motifs) -> Bool { !intersection(other).isEmpty }
}
