import Testing
import Foundation
@testable import MushKit

// Golden scenarios for docs/04-BRAIN-HEALTH.md. If a number here changes, the doc is
// wrong or the code is — never leave the two disagreeing.

private let engine = BrainHealthEngine()
private let day0 = Date(timeIntervalSince1970: 1_760_000_000)

private func makeDay(
    minutes: Int,
    budget: Int = 60,
    focus: Int = 0,
    overrides: Int = 0,
    windowsExpected: Int = 0,
    windowsHonored: Int = 0,
    signal: Bool = true
) -> DayRecord {
    DayRecord(
        date: day0,
        distractingMinutes: minutes,
        budgetMinutes: budget,
        focusSessionsCompleted: focus,
        overridesTaken: overrides,
        scheduledWindowsExpected: windowsExpected,
        scheduledWindowsHonored: windowsHonored,
        hasSignal: signal
    )
}

// MARK: - C1, the dominant term

@Test("Budget contribution hits its four specified anchors")
func budgetAnchors() {
    #expect(engine.budgetContribution(ratio: 0.0) == 10)
    #expect(engine.budgetContribution(ratio: 0.5) == 10)
    #expect(engine.budgetContribution(ratio: 1.0) == 0)
    #expect(engine.budgetContribution(ratio: 2.0) == -25)
    #expect(engine.budgetContribution(ratio: 9.0) == -25, "must floor, not keep falling")
}

@Test("Budget contribution is linear between anchors")
func budgetInterpolation() {
    #expect(abs(engine.budgetContribution(ratio: 0.75) - 5.0) < 0.0001)
    #expect(abs(engine.budgetContribution(ratio: 1.5) - (-12.5)) < 0.0001)
}

// MARK: - Whole-day scenarios

@Test("A near-perfect day is clamped at +15 rather than paying out 26")
func perfectDayClamps() {
    let day = makeDay(minutes: 20, focus: 3, windowsExpected: 1, windowsHonored: 1)
    let context = EvaluationContext(currentHealth: 70, currentStage: .foggy, streakBefore: 8)
    let entry = engine.evaluate(day: day, context: context)

    // +10 budget, +9 focus, +4 schedule, +3 streak (9 days / 3)
    #expect(entry.rawDelta == 26)
    #expect(entry.delta == 15)
    #expect(entry.wasClamped)
    #expect(entry.healthAfter == 85)
    #expect(entry.streakAfter == 9)
}

@Test("A disastrous day is clamped at -20 rather than taking 35")
func disastrousDayClamps() {
    let day = makeDay(minutes: 200, overrides: 5, windowsExpected: 1, windowsHonored: 0)
    let context = EvaluationContext(currentHealth: 70, currentStage: .foggy, streakBefore: 6)
    let entry = engine.evaluate(day: day, context: context)

    #expect(entry.rawDelta == -35)   // -25 budget, -10 overrides
    #expect(entry.delta == -20)
    #expect(entry.wasClamped)
    #expect(entry.healthAfter == 50)
    #expect(entry.streakAfter == 0, "a red day must break the streak")
}

@Test("Overrides never outweigh staying under budget")
func overridesAreSecondary() {
    // Under budget but took the escape hatch twice: +10 - 4 = +6. Still a good day.
    let day = makeDay(minutes: 30, overrides: 2)
    let entry = engine.evaluate(day: day, context: .init(currentHealth: 60))
    #expect(entry.delta == 6)
    #expect(entry.streakAfter == 1)
}

@Test("A blind day moves nothing and neither breaks nor extends the streak")
func noDataDayIsInert() {
    let day = makeDay(minutes: 0, signal: false)
    let context = EvaluationContext(currentHealth: 55, currentStage: .buzzed, streakBefore: 4)
    let entry = engine.evaluate(day: day, context: context)

    #expect(entry.contributions.isEmpty)
    #expect(entry.delta == 0)
    #expect(entry.healthAfter == 55)
    #expect(entry.streakAfter == 4, "absence of evidence is not a broken streak")
    #expect(entry.hadSignal == false)
    #expect(!day.isGreen, "a blind day must never count as green")
}

@Test("Zero minutes with a signal is a real green day, unlike a blind one")
func genuineZeroIsGreen() {
    let day = makeDay(minutes: 0, signal: true)
    #expect(day.isGreen)
    let entry = engine.evaluate(day: day, context: .init(currentHealth: 70))
    #expect(entry.delta == 10)
}

@Test("The comeback bonus fires only below 30 and only on a green day")
func comebackBonus() {
    let green = makeDay(minutes: 30)
    let low = engine.evaluate(day: green, context: .init(currentHealth: 25, currentStage: .melting))
    #expect(low.rawDelta == 13)          // +10 budget, +3 comeback
    #expect(low.contributions.contains { $0.kind == .comeback })

    let high = engine.evaluate(day: green, context: .init(currentHealth: 70, currentStage: .foggy))
    #expect(!high.contributions.contains { $0.kind == .comeback })

    let red = makeDay(minutes: 200)
    let redLow = engine.evaluate(day: red, context: .init(currentHealth: 20, currentStage: .mush))
    #expect(!redLow.contributions.contains { $0.kind == .comeback })
}

@Test("Streak bonus saturates at +5")
func streakSaturates() {
    let day = makeDay(minutes: 10)
    let entry = engine.evaluate(day: day, context: .init(currentHealth: 50, streakBefore: 200))
    let streak = entry.contributions.first { $0.kind == .streak }
    #expect(streak?.value == 5)
}

@Test("Schedule bonus requires both full adherence and zero overrides")
func scheduleBonusIsStrict() {
    let honored = makeDay(minutes: 30, windowsExpected: 2, windowsHonored: 2)
    #expect(engine.contributions(for: honored, context: .init(currentHealth: 70))
        .contains { $0.kind == .schedule })

    let overridden = makeDay(minutes: 30, overrides: 1, windowsExpected: 2, windowsHonored: 2)
    #expect(!engine.contributions(for: overridden, context: .init(currentHealth: 70))
        .contains { $0.kind == .schedule })

    let missed = makeDay(minutes: 30, windowsExpected: 2, windowsHonored: 1)
    #expect(!engine.contributions(for: missed, context: .init(currentHealth: 70))
        .contains { $0.kind == .schedule })
}

@Test("Health never leaves 0...100")
func healthIsBounded() {
    let awful = makeDay(minutes: 500, overrides: 5)
    let bottom = engine.evaluate(day: awful, context: .init(currentHealth: 5, currentStage: .mush))
    #expect(bottom.healthAfter == 0)

    let great = makeDay(minutes: 5, focus: 3)
    let top = engine.evaluate(day: great, context: .init(currentHealth: 98, currentStage: .crisp))
    #expect(top.healthAfter == 100)
}

// MARK: - Stages and hysteresis

@Test("Raw stage boundaries match the specified table")
func stageBoundaries() {
    #expect(BrainStage.raw(for: 100) == .crisp)
    #expect(BrainStage.raw(for: 85) == .crisp)
    #expect(BrainStage.raw(for: 84.9) == .foggy)
    #expect(BrainStage.raw(for: 65) == .foggy)
    #expect(BrainStage.raw(for: 64.9) == .buzzed)
    #expect(BrainStage.raw(for: 45) == .buzzed)
    #expect(BrainStage.raw(for: 44.9) == .melting)
    #expect(BrainStage.raw(for: 25) == .melting)
    #expect(BrainStage.raw(for: 0) == .mush)
}

@Test("A score oscillating around a boundary does not flip the character")
func hysteresisPreventsFlicker() {
    let h = 3.0
    // 64.9 is raw .buzzed, but we are coming from .foggy and have not cleared 62.
    #expect(BrainStage.resolved(health: 66, previous: .foggy, hysteresis: h) == .foggy)
    #expect(BrainStage.resolved(health: 64, previous: .foggy, hysteresis: h) == .foggy)
    #expect(BrainStage.resolved(health: 63, previous: .foggy, hysteresis: h) == .foggy)
    // Clearing the margin does move it.
    #expect(BrainStage.resolved(health: 62, previous: .foggy, hysteresis: h) == .buzzed)
}

@Test("Climbing a stage also costs the hysteresis margin")
func hysteresisOnTheWayUp() {
    #expect(BrainStage.resolved(health: 87, previous: .foggy, hysteresis: 3) == .foggy)
    #expect(BrainStage.resolved(health: 88, previous: .foggy, hysteresis: 3) == .crisp)
}

@Test("A large jump can cross several stages at once")
func multiStageJump() {
    #expect(BrainStage.resolved(health: 95, previous: .mush, hysteresis: 3) == .crisp)
    #expect(BrainStage.resolved(health: 2, previous: .crisp, hysteresis: 3) == .mush)
}

@Test("With no previous stage, resolution falls back to the raw table")
func noPreviousStage() {
    #expect(BrainStage.resolved(health: 70, previous: nil, hysteresis: 3) == .foggy)
}

// MARK: - The advertised decay/recovery speeds

@Test("100 to 0 takes five maximally-bad days; 0 to 100 takes seven good ones")
func decayAndRecoverySpeeds() {
    var health = 100.0
    var days = 0
    let awful = makeDay(minutes: 500, overrides: 5)
    while health > 0 {
        health = engine.evaluate(day: awful, context: .init(currentHealth: health)).healthAfter
        days += 1
        if days > 20 { break }
    }
    #expect(days == 5)

    health = 0
    days = 0
    let great = makeDay(minutes: 10, focus: 3, windowsExpected: 1, windowsHonored: 1)
    while health < 100 {
        health = engine.evaluate(day: great, context: .init(currentHealth: health)).healthAfter
        days += 1
        if days > 20 { break }
    }
    #expect(days == 7)
}
