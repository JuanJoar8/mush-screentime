import Testing
import Foundation
@testable import MushKit

// Fixtures ---------------------------------------------------------------------------

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
}

private func group(
    _ name: String,
    mode: BlockMode = .blocklist,
    budget: Int = 60,
    windows: [ScheduleWindow] = [],
    enabled: Bool = true
) -> RuleGroup {
    RuleGroup(
        name: name,
        mode: mode,
        selectionKey: "sel.\(name)",
        budgetMinutes: budget,
        windows: windows,
        isEnabled: enabled
    )
}

// MARK: - Rule groups

@Test("An active allowlist group suspends every other group")
func allowlistIsExclusive() {
    let set = RuleSet(groups: [
        group("Social"),
        group("Deep work", mode: .allowlist, budget: 0),
        group("News")
    ])

    let resolution = set.resolve(at: at(2, 10), calendar: utc)

    #expect(resolution.active.count == 1)
    #expect(resolution.active.first?.mode == .allowlist)
    #expect(resolution.suspended.count == 2)
    #expect(resolution.suspended.allSatisfy { $0.reason == .allowlistExclusive })
}

@Test("Without an allowlist every enabled, in-window group is active")
func blocklistsCoexist() {
    let set = RuleSet(groups: [group("Social"), group("News"), group("Off", enabled: false)])
    let resolution = set.resolve(at: at(2, 10), calendar: utc)
    #expect(resolution.active.count == 2)
    #expect(resolution.suspended.isEmpty)
}

@Test("A group with windows is suspended outside them, and says why")
func windowSuspension() {
    let bedtime = ScheduleWindow(name: "Bedtime", startMinute: 23 * 60, endMinute: 7 * 60)
    let set = RuleSet(groups: [group("Night", windows: [bedtime])])

    let asleep = set.resolve(at: at(2, 2), calendar: utc)
    #expect(asleep.active.count == 1, "02:00 is inside a window that crosses midnight")

    let awake = set.resolve(at: at(2, 12), calendar: utc)
    #expect(awake.active.isEmpty)
    #expect(awake.suspended.first?.reason == .outsideWindow)
}

@Test("An allowlist outside its window does not suspend anything")
func dormantAllowlistIsHarmless() {
    let workday = ScheduleWindow(name: "Work", startMinute: 9 * 60, endMinute: 17 * 60)
    let set = RuleSet(groups: [
        group("Deep work", mode: .allowlist, budget: 0, windows: [workday]),
        group("Social")
    ])

    let evening = set.resolve(at: at(2, 20), calendar: utc)
    #expect(evening.active.map(\.name) == ["Social"])
    #expect(evening.suspended.first?.reason == .outsideWindow)
}

@Test("The effective budget is the tightest active one, never the sum")
func tightestBudgetWins() {
    let set = RuleSet(groups: [group("A", budget: 45), group("B", budget: 30), group("C", budget: 0)])
    #expect(set.effectiveBudgetMinutes(at: at(2, 10), calendar: utc) == 30)
}

// MARK: - Frequency limit

@Test("Quarter-hours are counted once however many firings land in them")
func quarterHoursAreDistinct() {
    let firings = [
        LadderFiring(rung: 1, at: at(2, 9, 1)),
        LadderFiring(rung: 2, at: at(2, 9, 6)),
        LadderFiring(rung: 3, at: at(2, 9, 12)),   // all three inside 09:00-09:15
        LadderFiring(rung: 4, at: at(2, 14, 30))
    ]
    #expect(QuarterHourCounter.touched(firings, calendar: utc).count == 2)
}

@Test("The frequency limit trips on reaching the cap, not after exceeding it")
func frequencyLimitTrips() {
    let limit = FrequencyLimit(maxTouchedQuarterHours: 2)
    let two = [LadderFiring(rung: 1, at: at(2, 9, 0)), LadderFiring(rung: 2, at: at(2, 10, 0))]
    #expect(QuarterHourCounter.isExceeded(two, limit: limit, calendar: utc))

    let one = [LadderFiring(rung: 1, at: at(2, 9, 0))]
    #expect(!QuarterHourCounter.isExceeded(one, limit: limit, calendar: utc))
}

@Test("A frequency limit cannot be set outside one day's worth of quarter-hours")
func frequencyLimitClamps() {
    #expect(FrequencyLimit(maxTouchedQuarterHours: 0).maxTouchedQuarterHours == 1)
    #expect(FrequencyLimit(maxTouchedQuarterHours: 500).maxTouchedQuarterHours == 96)
}

// MARK: - Milestones

@Test("A fall past a level fires once, and hovering under it stays quiet")
func milestoneFiresOnce() {
    let watcher = MilestoneWatcher(hysteresis: 3)
    var state = watcher.seed(at: 80)

    #expect(watcher.evaluate(health: 49, state: &state).count == 2, "75 and 50 both crossed")
    #expect(watcher.evaluate(health: 48, state: &state).isEmpty)
    #expect(watcher.evaluate(health: 51, state: &state).isEmpty, "51 is inside the 50 hysteresis band")
    #expect(watcher.evaluate(health: 49, state: &state).isEmpty)
}

@Test("Recovery has to clear the hysteresis band before it re-arms")
func milestoneRearms() {
    let watcher = MilestoneWatcher(hysteresis: 3)
    var state = watcher.seed(at: 80)
    _ = watcher.evaluate(health: 49, state: &state)

    #expect(watcher.evaluate(health: 52, state: &state).isEmpty)

    let recovered = watcher.evaluate(health: 53, state: &state)
    #expect(recovered.count == 1)
    #expect(recovered.first?.direction == .rising)
    #expect(recovered.first?.milestone == .fifty)

    #expect(watcher.evaluate(health: 49, state: &state).count == 1, "re-armed, so it can fall again")
}

@Test("Seeding stops a fresh low install announcing every level at once")
func milestoneSeeding() {
    let watcher = MilestoneWatcher()
    var state = watcher.seed(at: 8)
    #expect(watcher.evaluate(health: 8, state: &state).isEmpty)
    #expect(state.announcedFalling == [10, 25, 50, 75])
}

@Test("A climb only reports the levels it was actually under")
func milestoneRiseIsBounded() {
    let watcher = MilestoneWatcher()
    // Seeded at 70: below 75, above the other three. Climbing to 90 genuinely crosses 75
    // and genuinely does not cross 50, 25 or 10 — it was never under them.
    var state = watcher.seed(at: 70)
    #expect(state.announcedFalling == [75])

    let crossings = watcher.evaluate(health: 90, state: &state)
    #expect(crossings.count == 1)
    #expect(crossings.first?.milestone == .seventyFive)
    #expect(crossings.first?.direction == .rising)
    #expect(state.announcedFalling.isEmpty)
}

@Test("One plunge produces one notification: the deepest level crossed")
func milestoneHeadline() {
    let watcher = MilestoneWatcher()
    var state = watcher.seed(at: 90)
    let crossings = watcher.evaluate(health: 5, state: &state)
    #expect(crossings.count == 4)
    #expect(watcher.headline(from: crossings)?.milestone == .ten)
}

// MARK: - Gems

private func gemContext(days: [DayRecord], streak: Int = 0, health: Double = 70) -> GemContext {
    GemContext(days: days, entries: [], streak: streak, health: health, stage: .foggy, now: at(9, 12))
}

@Test("Gems unlock from the ledger and never re-lock")
func gemsAreSticky() {
    // Past the backfill: this test is about stickiness, not about the first pass.
    var state = GemState(hasBackfilled: true)
    let good = DayRecord(date: at(1, 0), distractingMinutes: 20, budgetMinutes: 60, shieldsShown: 0)

    let first = GemEvaluator.evaluate(gemContext(days: [good]), state: &state)
    #expect(first.contains { $0.id == "under-half" })
    #expect(first.contains { $0.id == "quiet-day" })

    let bad = DayRecord(date: at(2, 0), distractingMinutes: 300, budgetMinutes: 60, shieldsShown: 9)
    _ = GemEvaluator.evaluate(gemContext(days: [bad]), state: &state)
    #expect(state.unlocked.contains("under-half"), "a gem records what happened; it cannot be taken back")
}

@Test("A blind day earns nothing")
func gemsIgnoreBlindDays() {
    // Past the backfill, so an empty result means the day genuinely earned nothing
    // rather than that the first pass swallowed it.
    var state = GemState(hasBackfilled: true)
    let blind = DayRecord(date: at(1, 0), distractingMinutes: 0, budgetMinutes: 60, hasSignal: false)
    let unlocked = GemEvaluator.evaluate(gemContext(days: [blind]), state: &state)
    #expect(!unlocked.contains { $0.id == "first-signal" })
    #expect(!unlocked.contains { $0.id == "under-half" })
}

@Test("Every gem's requirement text is unique and its id is stable")
func gemCatalogueIsWellFormed() {
    let ids = GemCatalog.all.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(GemCatalog.all.allSatisfy { !$0.requirement.isEmpty })
    #expect(GemCatalog.gem(id: "streak-7")?.title == "Seven")
}

@Test("A clean run is broken by an override, not merely dented")
func cleanRunResets() {
    let days = (1...9).map { index in
        DayRecord(
            date: at(index, 0),
            distractingMinutes: 10,
            budgetMinutes: 60,
            overridesTaken: index == 5 ? 1 : 0
        )
    }
    #expect(gemContext(days: days).longestCleanRun == 4)
}

// MARK: - Weekly digest

@Test("Two weeks with too many blind days are reported as not comparable")
func digestRefusesBadComparison() {
    var days: [DayRecord] = []
    for offset in 1...14 {
        days.append(
            DayRecord(
                date: at(offset, 0),
                distractingMinutes: 30,
                budgetMinutes: 60,
                hasSignal: offset > 5
            )
        )
    }
    let digest = WeeklyDigestBuilder.build(days: days, entries: [], now: at(15, 12), calendar: utc)
    #expect(!digest.isComparable)
    #expect(digest.headline.contains("Not comparable"))
}

@Test("A comparable fortnight reports the minute difference in the right direction")
func digestComparesMinutes() {
    var days: [DayRecord] = []
    for offset in 1...7 {
        days.append(DayRecord(date: at(offset, 0), distractingMinutes: 60, budgetMinutes: 60))
    }
    for offset in 8...14 {
        days.append(DayRecord(date: at(offset, 0), distractingMinutes: 40, budgetMinutes: 60))
    }
    let digest = WeeklyDigestBuilder.build(days: days, entries: [], now: at(15, 12), calendar: utc)
    #expect(digest.isComparable)
    #expect(digest.minutesDelta == -140)
    #expect(digest.headline == "140 minutes less than the week before.")
}

@Test("The biggest mover is the largest magnitude, penalty or bonus")
func digestBiggestMover() {
    let entry = HealthEntry(
        date: at(2, 0),
        healthBefore: 60,
        healthAfter: 55,
        contributions: [
            Contribution(kind: .focus, value: 6, reason: "focus"),
            Contribution(kind: .overrides, value: -9, reason: "overrides")
        ],
        rawDelta: -3,
        delta: -3,
        wasClamped: false,
        stageBefore: .foggy,
        stageAfter: .foggy,
        hadSignal: true,
        streakAfter: 0
    )
    let mover = WeeklyDigestBuilder.biggestMover(in: [entry])
    #expect(mover?.kind == .overrides)
    #expect(mover?.reason == "Overrides cost 9 points")
}

// MARK: - Widget snapshot

@Test("A stale snapshot timestamps itself instead of pretending to be live")
func snapshotFreshness() {
    let snapshot = WidgetSnapshot(
        health: 62, stage: .foggy, distractingMinutes: 23, budgetMinutes: 60,
        streak: 3, hasSignal: true, capturedAt: at(2, 9)
    )
    #expect(snapshot.freshness(at: at(2, 9, 5)) == nil)
    #expect(snapshot.freshness(at: at(2, 11)) != nil)
}

@Test("The placeholder is explicitly signal-less so the widget can draw hollow")
func snapshotPlaceholder() {
    #expect(!WidgetSnapshot.placeholder.hasSignal)
    #expect(WidgetSnapshot.placeholder.minutesLeft == 60)
}

// MARK: - Interventions and maintenance

@Test("Only Standard gates its grant behind a hold")
func interventionGating() {
    #expect(Intervention.forStrictness(.gentle) == nil)
    #expect(Intervention.forStrictness(.standard)?.seconds == 20)
    #expect(Intervention.forStrictness(.strict) == nil)
    #expect(Intervention.forStrictness(.sealed) == nil)
}

@Test("A hold has to be unbroken for the full duration")
func interventionSatisfaction() {
    let hold = Intervention(seconds: 20, prompt: "Hold.")
    #expect(!hold.isSatisfied(heldFor: 19.9))
    #expect(hold.isSatisfied(heldFor: 20))
    #expect(hold.progress(heldFor: 40) == 1)
}

@Test("A grant is only called stale once wall-clock time makes it impossible")
func staleGrants() {
    let grant = Grant(storeName: "limit", issuedAt: at(2, 9), usageMinutes: 5)
    #expect(GrantMaintenance.stale([grant], now: at(2, 9, 4)).isEmpty)
    #expect(GrantMaintenance.stale([grant], now: at(2, 9, 6)).count == 1)
}

@Test("Repairs declare whether they open a gap while running")
func maintenanceHonesty() {
    #expect(MaintenanceAction.reapplyShields.opensAGapWhileRunning)
    #expect(!MaintenanceAction.clearStaleGrants.opensAGapWhileRunning)
    #expect(MaintenanceAction.allCases.allSatisfy { !$0.explanation.isEmpty })
}

@Test("Seeding marks itself done so a healthy user is not re-seeded into silence")
func milestoneSeedIsRecorded() {
    let watcher = MilestoneWatcher()
    #expect(!MilestoneState().hasSeeded)
    #expect(watcher.seed(at: 90).hasSeeded)
}

@Test("A ledger saved before a field existed still decodes")
func ledgerDecodesLeniently() throws {
    // Exactly what an older build would have written: no rules, gems or milestones.
    //
    // `ladderLogs` is `[Date: LadderLog]`, and a dictionary whose key is neither String
    // nor Int is encoded by `JSONEncoder` as a flat array of alternating keys and values,
    // not an object. Writing `{}` here would test a file shape the app never produces.
    let legacy = Data("""
    {"days":[],"entries":[],"ladderLogs":[],"activeGrants":[],
     "focusSessions":[],"health":64.5,"stage":1,"streak":2}
    """.utf8)

    let state = try JSONDecoder().decode(LedgerState.self, from: legacy)
    #expect(state.health == 64.5)
    #expect(state.streak == 2)
    #expect(state.rules.groups.isEmpty)
    #expect(state.gems.unlocked.isEmpty)
    #expect(!state.milestones.hasSeeded)
}

@Test("Gem shapes are stable across launches, not seeded by the process hash")
func gemSeedIsDeterministic() {
    // The badge derives its polygon from this sum. `hashValue` would differ per launch,
    // so the same gem would be a different shape every time the app opened.
    func seed(_ id: String) -> Int { id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }
    #expect(seed("streak-7") == seed("streak-7"))
    // Sides and rotation, joined — a tuple cannot be a Set element in Swift.
    let shapes = Set(GemCatalog.all.map { "\(seed($0.id) % 4)/\(seed($0.id) % 12)" })
    #expect(shapes.count >= 8, "twelve gems should not collapse into a handful of shapes")
}

@Test("The first evaluation backfills history silently, the next one announces")
func gemsBackfillQuietly() {
    var state = GemState()
    let earned = DayRecord(date: at(1, 0), distractingMinutes: 20, budgetMinutes: 60)

    let first = GemEvaluator.evaluate(gemContext(days: [earned]), state: &state)
    #expect(first.isEmpty, "days that already happened are not achievements")
    #expect(state.unlocked.contains("under-half"), "but they are still on the shelf")
    #expect(state.hasBackfilled)

    // A gem earned after the backfill is announced normally.
    let announced = GemEvaluator.evaluate(
        gemContext(days: [earned], streak: 7), state: &state
    )
    #expect(announced.contains { $0.id == "streak-7" })
}
