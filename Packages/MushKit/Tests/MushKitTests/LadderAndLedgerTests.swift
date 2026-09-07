import Testing
import Foundation
@testable import MushKit

// MARK: - Ladder

@Test("Ladder climbs to twice the budget so overshoot stays measurable")
func ladderShape() {
    let ladder = ThresholdLadder(stepMinutes: 5, maxRungs: 48)
    let t = ladder.thresholds(budgetMinutes: 60)
    #expect(t.first == 5)
    #expect(t.last == 120)
    #expect(t.count == 24)
}

@Test("Ladder respects the event-count guardrail")
func ladderCap() {
    let ladder = ThresholdLadder(stepMinutes: 5, maxRungs: 48)
    let t = ladder.thresholds(budgetMinutes: 500)
    #expect(t.count == 48, "must not register unbounded events; Q2 is undocumented")
    #expect(t.last == 240)
}

@Test("A missing budget produces no ladder at all")
func ladderNeedsBudget() {
    #expect(ThresholdLadder().thresholds(budgetMinutes: 0).isEmpty)
}

@Test("Budget rung rounds up so a partial rung still trips the limit")
func budgetRung() {
    let ladder = ThresholdLadder(stepMinutes: 5)
    #expect(ladder.budgetRung(budgetMinutes: 60) == 12)
    #expect(ladder.budgetRung(budgetMinutes: 62) == 13)
    #expect(ladder.budgetRung(budgetMinutes: 1) == 1)
}

// MARK: - Validator (the iOS 26.x defence)

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)
private let validator = ThresholdValidator(stepMinutes: 5)

@Test("First firing of the day is always accepted")
func firstFiringAccepted() {
    #expect(validator.decide(LadderFiring(rung: 1, at: t0), lastAccepted: nil) == .accepted)
}

@Test("Usage cannot accumulate faster than wall-clock time")
func impossiblySoonIsRejected() {
    let last = LadderFiring(rung: 1, at: t0)
    // Claims another 5 usage-minutes, 40 seconds later. Physically impossible.
    let firing = LadderFiring(rung: 2, at: t0.addingTimeInterval(40))
    #expect(validator.decide(firing, lastAccepted: last) == .rejected(.impossiblySoon))
}

@Test("A plausibly-timed firing is accepted, with tolerance for callback latency")
func plausibleFiringAccepted() {
    let last = LadderFiring(rung: 1, at: t0)
    #expect(validator.decide(LadderFiring(rung: 2, at: t0.addingTimeInterval(300)),
                             lastAccepted: last) == .accepted)
    // 250s against a claimed 300s: inside the 0.8 tolerance.
    #expect(validator.decide(LadderFiring(rung: 2, at: t0.addingTimeInterval(250)),
                             lastAccepted: last) == .accepted)
    // 239s is outside it.
    #expect(validator.decide(LadderFiring(rung: 2, at: t0.addingTimeInterval(239)),
                             lastAccepted: last) == .rejected(.impossiblySoon))
}

@Test("Duplicate and backwards rungs are rejected distinctly")
func duplicateAndRegression() {
    let last = LadderFiring(rung: 5, at: t0)
    #expect(validator.decide(LadderFiring(rung: 5, at: t0.addingTimeInterval(600)),
                             lastAccepted: last) == .rejected(.duplicate))
    #expect(validator.decide(LadderFiring(rung: 3, at: t0.addingTimeInterval(600)),
                             lastAccepted: last) == .rejected(.regression))
}

@Test("A burst of false-positive firings cannot inflate the day")
func burstIsContained() {
    var log = LadderLog()
    // Twelve firings in twelve seconds, the pattern reported on iOS 26.2.
    for rung in 1...12 {
        _ = log.record(LadderFiring(rung: rung, at: t0.addingTimeInterval(Double(rung))),
                       validator: validator)
    }
    #expect(log.accepted.count == 1, "only the first can be trusted")
    #expect(log.rejected.count == 11)
    #expect(log.highestAcceptedRung == 1)
    #expect(log.hasSignal, "rejected firings still prove the extension woke up")
}

// MARK: - Ledger

@Test("Recording firings builds the day record from accepted rungs only")
func ledgerRecordsFirings() throws {
    let store = InMemoryLedgerStore()
    let ledger = UsageLedger(store: store)

    #expect(try ledger.recordFiring(rung: 1, at: t0) == .accepted)
    #expect(try ledger.recordFiring(rung: 2, at: t0.addingTimeInterval(400)) == .accepted)
    #expect(try ledger.recordFiring(rung: 3, at: t0.addingTimeInterval(410)) == .rejected(.impossiblySoon))

    let state = try store.load()
    let day = try #require(state.days.first)
    #expect(day.distractingMinutes == 10, "rung 3 was rejected, so it must not count")
    #expect(day.hasSignal)
}

@Test("Rollover is idempotent")
func rolloverIsIdempotent() throws {
    let store = InMemoryLedgerStore()
    let calendar = Calendar.current
    let ledger = UsageLedger(store: store, calendar: calendar)

    var state = try store.load()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: t0))!
    state.days = [DayRecord(date: yesterday, distractingMinutes: 30, budgetMinutes: 60)]
    try store.save(state)

    let first = try ledger.rollover(now: t0)
    let second = try ledger.rollover(now: t0)
    #expect(first.count == 1)
    #expect(second.isEmpty, "committing twice would double-count the day")
}

@Test("Rollover catches up across missed days in chronological order")
func rolloverCatchesUp() throws {
    let store = InMemoryLedgerStore()
    let calendar = Calendar.current
    let ledger = UsageLedger(store: store, calendar: calendar)

    var state = try store.load()
    state.health = 70
    let today = calendar.startOfDay(for: t0)
    state.days = (1...4).map { offset in
        DayRecord(
            date: calendar.date(byAdding: .day, value: -offset, to: today)!,
            distractingMinutes: 20,
            budgetMinutes: 60
        )
    }
    try store.save(state)

    let entries = try ledger.rollover(now: t0)
    #expect(entries.count == 4)
    #expect(entries == entries.sorted { $0.date < $1.date }, "order decides streaks")
    #expect(try store.load().streak == 4)
    // 70 -> 80 -> 90 -> clamped at 100 on day three, once the streak bonus lands.
    #expect(try store.load().health == 100)
}

@Test("Today is never committed early")
func todayIsNotCommitted() throws {
    let store = InMemoryLedgerStore()
    let calendar = Calendar.current
    let ledger = UsageLedger(store: store, calendar: calendar)

    var state = try store.load()
    state.days = [DayRecord(date: calendar.startOfDay(for: t0), distractingMinutes: 10)]
    try store.save(state)

    #expect(try ledger.rollover(now: t0).isEmpty)
}

@Test("Improvement compares two windows and ignores blind days")
func improvementIgnoresBlindDays() throws {
    let store = InMemoryLedgerStore()
    let calendar = Calendar.current
    let ledger = UsageLedger(store: store, calendar: calendar)
    let today = calendar.startOfDay(for: t0)

    var state = try store.load()
    // Recent week averages 30; prior week averages 60. That is a 50% improvement.
    for offset in 0..<7 {
        state.days.append(DayRecord(date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                                    distractingMinutes: 30))
    }
    for offset in 7..<14 {
        state.days.append(DayRecord(date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                                    distractingMinutes: 60))
    }
    try store.save(state)

    // Computed outside the macro: #require expands its argument into a closure, which
    // strands the `try`.
    let measured = try ledger.improvement(days: 7, now: t0)
    let improvement = try #require(measured)
    #expect(abs(improvement - (-0.5)) < 0.0001)
}

@Test("Mock seeding runs through the real engine and lands in a plausible state")
func mockSeedingIsRealistic() throws {
    let store = InMemoryLedgerStore()
    try MockScreenTimeProvider.seed(.realisticFortnight, into: store, endingOn: t0)

    let state = try store.load()
    #expect(state.entries.count == 13, "every day but today should be committed")
    #expect(state.health > 0 && state.health < 100)
    #expect(state.days.contains { !$0.hasSignal }, "the blind day must survive seeding")

    // The scenario ends on a three-day recovery run.
    #expect(state.streak == 3)
}

// MARK: - Windows

@Test("A window shorter than 15 minutes is not schedulable")
func shortWindowRejected() {
    let tooShort = ScheduleWindow(name: "Blip", startMinute: 600, endMinute: 610)
    #expect(!tooShort.isSchedulable, "DeviceActivitySchedule enforces a 15-minute floor")

    let ok = ScheduleWindow(name: "Focus", startMinute: 600, endMinute: 660)
    #expect(ok.isSchedulable)
}

@Test("A bedtime window that wraps past midnight measures correctly")
func midnightWrap() {
    let bedtime = ScheduleWindow(name: "Bedtime", startMinute: 22 * 60, endMinute: 7 * 60)
    #expect(bedtime.crossesMidnight)
    #expect(bedtime.durationMinutes == 9 * 60)
    #expect(bedtime.isSchedulable)
}

@Test("MonitoringPlan validates the 15-minute floor before we ever call Apple")
func planValidation() {
    #expect(!MonitoringPlan(activityName: "a", startMinute: 100, endMinute: 110).isValid)
    #expect(MonitoringPlan(activityName: "a", startMinute: 100, endMinute: 115).isValid)
    #expect(MonitoringPlan(activityName: "a", startMinute: 1400, endMinute: 20).isValid)
}
