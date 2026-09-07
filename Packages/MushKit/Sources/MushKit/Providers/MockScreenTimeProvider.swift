import Foundation

/// Runs the whole product without Apple's frameworks.
///
/// This is not a stub for its own sake. Family Controls does not work in the Simulator
/// at all, even with a paid membership, so without this nothing could ever be previewed —
/// and in the current account situation it is the *only* way to run Mush end to end
/// (docs/08-DECISIONS.md D7).
///
/// The synthetic data is deliberately plausible rather than flattering: a realistic week
/// has bad days in it, and a UI that has only ever been seen against a perfect week is a
/// UI that has not been designed.
public actor MockScreenTimeProvider: ScreenTimeProviding {

    public struct Scenario: Sendable, Equatable {
        /// Distracting minutes per day, oldest first. `nil` is a blind day — no signal —
        /// which must render hollow and score zero rather than looking like a good day.
        public var dailyMinutes: [Int?]
        public var budgetMinutes: Int
        public var focusPerDay: [Int]
        public var overridesPerDay: [Int]
        public var startingHealth: Double

        public init(
            dailyMinutes: [Int?],
            budgetMinutes: Int = 60,
            focusPerDay: [Int] = [],
            overridesPerDay: [Int] = [],
            startingHealth: Double = 70
        ) {
            self.dailyMinutes = dailyMinutes
            self.budgetMinutes = budgetMinutes
            self.focusPerDay = focusPerDay
            self.overridesPerDay = overridesPerDay
            self.startingHealth = startingHealth
        }

        /// Fourteen days that exercise every branch of the model: a decent start, a
        /// three-day collapse, a blind day, then a recovery arc that crosses two stage
        /// boundaries.
        public static let realisticFortnight = Scenario(
            dailyMinutes: [45, 52, 38, 120, 190, 240, 165, nil, 95, 70, 55, 40, 35, 28],
            budgetMinutes: 60,
            focusPerDay:   [1, 0, 2, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 2],
            overridesPerDay: [0, 1, 0, 3, 5, 4, 2, 0, 1, 0, 0, 0, 0, 0],
            startingHealth: 78
        )

        /// A user who has never had a good day. Exercises the floor and the comeback bonus.
        public static let roughWeek = Scenario(
            dailyMinutes: [180, 210, 240, 195, 260, 300, 220],
            budgetMinutes: 60,
            overridesPerDay: [4, 5, 5, 3, 5, 5, 4],
            startingHealth: 45
        )
    }

    private var status: MushAuthorizationStatus
    private var shields: Set<String> = []
    private var activities: Set<String> = []
    private var pickedCount: Int

    public init(status: MushAuthorizationStatus = .approved, selectionCount: Int = 4) {
        self.status = status
        self.pickedCount = selectionCount
    }

    public var authorizationStatus: MushAuthorizationStatus { status }
    public var selectionCount: Int { pickedCount }

    public func requestAuthorization() async throws {
        guard status != .unavailable else {
            throw ScreenTimeError.unavailable("Family Controls is not available here.")
        }
        status = .approved
    }

    public func applyShield(_ target: ShieldTarget, store: String) async throws {
        guard status.canShield else { throw ScreenTimeError.notAuthorized }
        shields.insert(store)
    }

    public func clearShield(store: String) async throws { shields.remove(store) }
    public func activeShieldStores() async -> [String] { Array(shields).sorted() }

    public func startMonitoring(_ plan: MonitoringPlan) async throws {
        guard status.canShield else { throw ScreenTimeError.notAuthorized }
        guard plan.isValid else { throw ScreenTimeError.scheduleTooShort }
        activities.insert(plan.activityName)
    }

    public func stopMonitoring(activityName: String) async throws {
        activities.remove(activityName)
    }

    public func activeActivities() async -> [String] { Array(activities).sorted() }

    // MARK: Seeding

    /// Replays a scenario through the real `UsageLedger` and `BrainHealthEngine`, so the
    /// Simulator shows numbers produced by the same code path as the device, not by a
    /// parallel fake.
    public static func seed(
        _ scenario: Scenario,
        into store: LedgerStoring,
        endingOn endDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        let ladder = ThresholdLadder()
        let ledger = UsageLedger(store: store, ladder: ladder, calendar: calendar)

        var state = try store.load()
        state.health = scenario.startingHealth
        state.stage = BrainStage.raw(for: scenario.startingHealth)
        try store.save(state)

        let count = scenario.dailyMinutes.count
        for (index, minutes) in scenario.dailyMinutes.enumerated() {
            let offset = -(count - 1 - index)
            guard let date = calendar.date(byAdding: .day, value: offset,
                                           to: calendar.startOfDay(for: endDate)) else { continue }

            var current = try store.load()
            var record = DayRecord(date: date, budgetMinutes: scenario.budgetMinutes)

            if let minutes {
                // Quantise to the ladder, exactly as a real day would arrive.
                let rung = minutes / ladder.stepMinutes
                record.distractingMinutes = ladder.minutes(atRung: rung)
                record.hasSignal = true
                record.focusSessionsCompleted = scenario.focusPerDay[safe: index] ?? 0
                record.focusMinutes = (scenario.focusPerDay[safe: index] ?? 0) * 25
                record.overridesTaken = scenario.overridesPerDay[safe: index] ?? 0
                record.shieldsShown = record.overridesTaken + (minutes > scenario.budgetMinutes ? 2 : 0)
                record.grantsIssued = record.overridesTaken
                record.scheduledWindowsExpected = 1
                record.scheduledWindowsHonored = record.overridesTaken == 0 ? 1 : 0
            } else {
                record.hasSignal = false
            }

            current.days.removeAll { $0.date == record.date }
            current.days.append(record)
            current.days.sort { $0.date < $1.date }
            try store.save(current)
        }

        // Commit every day but today, through the real rollover.
        try ledger.rollover(now: endDate)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
