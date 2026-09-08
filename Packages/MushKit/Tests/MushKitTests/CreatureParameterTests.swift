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
    // Ten of fifteen, measured against a real minimum of thirteen — the closest pair is
    // crisp and mush, which sit at opposite ends and still share two numbers. Three of
    // slack, so an honest tuning change does not trip it and a stage collapsing into a
    // recolour of its neighbour does.
    func signature(_ p: CreatureParameters) -> [Double] {
        [
            Double(p.browTilt), Double(p.browLift), Double(p.lid), Double(p.open),
            Double(p.sag), Double(p.spread), Double(p.sheen), Double(p.pupil),
            Double(p.mouth), Double(p.armLeft), Double(p.armRight), Double(p.jitter),
            p.blinkInterval, Double(p.foldsPerSide), Double(p.motifs.rawValue)
        ]
    }

    for (i, a) in ladder.enumerated() {
        for b in ladder.dropFirst(i + 1) {
            let left = signature(params(a))
            let right = signature(params(b))
            let differing = zip(left, right).filter { $0.0 != $0.1 }.count
            #expect(
                differing >= 10,
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

private extension Motifs {
    func intersects(_ other: Motifs) -> Bool { !intersection(other).isEmpty }
}
