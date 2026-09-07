import Foundation

/// The persisted state shared between the app and the writable extensions.
///
/// Deliberately plain `Codable` written to an App Group file with atomic replacement.
/// No CoreData or SwiftData: the monitor extension runs under a tight memory budget and
/// may be woken for milliseconds, and the data volume is one record per day
/// (docs/08-DECISIONS.md D6).
public struct LedgerState: Codable, Sendable, Equatable {
    public var days: [DayRecord] = []
    public var entries: [HealthEntry] = []
    public var ladderLogs: [Date: LadderLog] = [:]
    public var activeGrants: [Grant] = []
    public var focusSessions: [FocusSession] = []
    public var health: Double = BrainHealthConfig().startingHealth
    public var stage: BrainStage = .foggy
    public var streak: Int = 0
    /// Day the last rollover committed, so we never double-commit.
    public var lastRollover: Date?

    public init() {}
}

/// Where `LedgerState` lives. Abstracted so tests and the mock provider can run entirely
/// in memory.
public protocol LedgerStoring: Sendable {
    func load() throws -> LedgerState
    func save(_ state: LedgerState) throws
}

/// In-memory store for tests and Simulator runs.
public final class InMemoryLedgerStore: LedgerStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var state: LedgerState

    public init(state: LedgerState = LedgerState()) { self.state = state }

    public func load() throws -> LedgerState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    public func save(_ newValue: LedgerState) throws {
        lock.lock(); defer { lock.unlock() }
        state = newValue
    }
}

/// App Group file store. The only channel between the app and the writable extensions.
public final class FileLedgerStore: LedgerStoring, @unchecked Sendable {
    public enum StoreError: Error, Sendable {
        /// The App Group container is missing — almost always an entitlement or
        /// provisioning problem rather than a code problem.
        case containerUnavailable(String)
    }

    private let url: URL
    private let lock = NSLock()

    public init(appGroup: String = MushIdentifiers.appGroup, filename: String = "ledger.json") throws {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw StoreError.containerUnavailable(appGroup)
        }
        self.url = container.appendingPathComponent(filename)
    }

    public func load() throws -> LedgerState {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: url.path) else { return LedgerState() }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.mush.decode(LedgerState.self, from: data)
    }

    public func save(_ state: LedgerState) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try JSONEncoder.mush.encode(state)
        // Atomic: an extension can be killed mid-write, and a truncated ledger would
        // lose the user's entire history.
        try data.write(to: url, options: [.atomic])
    }
}

extension JSONEncoder {
    static var mush: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var mush: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - Ledger

/// Reads and mutates `LedgerState`, and owns the daily rollover.
public struct UsageLedger: Sendable {
    public let store: LedgerStoring
    public let engine: BrainHealthEngine
    public let ladder: ThresholdLadder
    public let calendar: Calendar

    public init(
        store: LedgerStoring,
        engine: BrainHealthEngine = BrainHealthEngine(),
        ladder: ThresholdLadder = ThresholdLadder(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.engine = engine
        self.ladder = ladder
        self.calendar = calendar
    }

    public func day(for date: Date) -> Date { calendar.startOfDay(for: date) }

    // MARK: Recording

    /// Called from the monitor extension on every `eventDidReachThreshold`.
    /// Returns whether the firing survived validation.
    @discardableResult
    public func recordFiring(rung: Int, at date: Date) throws -> FiringDecision {
        var state = try store.load()
        let key = day(for: date)
        var log = state.ladderLogs[key] ?? LadderLog()
        let validator = ThresholdValidator(stepMinutes: ladder.stepMinutes)
        let decision = log.record(LadderFiring(rung: rung, at: date), validator: validator)
        state.ladderLogs[key] = log

        var record = state.days.first { $0.date == key } ?? DayRecord(date: key)
        record.distractingMinutes = ladder.minutes(atRung: log.highestAcceptedRung)
        record.hasSignal = log.hasSignal
        upsert(record, in: &state)

        try store.save(state)
        return decision
    }

    /// Called from the shield-action extension. These counters are the raw material for
    /// contributions C3 and C4.
    public func recordShieldEvent(
        shown: Int = 0,
        overrides: Int = 0,
        grants: Int = 0,
        at date: Date = Date()
    ) throws {
        var state = try store.load()
        let key = day(for: date)
        var record = state.days.first { $0.date == key } ?? DayRecord(date: key)
        record.shieldsShown += shown
        record.overridesTaken += overrides
        record.grantsIssued += grants
        // A shield firing proves the pipeline is alive even if no rung landed.
        record.hasSignal = true
        upsert(record, in: &state)
        try store.save(state)
    }

    /// A scheduled window began. Raises the day's expectation count, which contribution
    /// C4 later checks against the honored count.
    public func recordWindowStarted(at date: Date = Date()) throws {
        var state = try store.load()
        let key = day(for: date)
        var record = state.days.first { $0.date == key } ?? DayRecord(date: key)
        record.scheduledWindowsExpected += 1
        record.hasSignal = true
        upsert(record, in: &state)
        try store.save(state)
    }

    /// A scheduled window ran to its natural end. C4 additionally requires zero
    /// overrides on the day, so this only needs to record completion.
    public func recordWindowEnded(at date: Date = Date()) throws {
        var state = try store.load()
        let key = day(for: date)
        var record = state.days.first { $0.date == key } ?? DayRecord(date: key)
        record.scheduledWindowsHonored += 1
        record.hasSignal = true
        upsert(record, in: &state)
        try store.save(state)
    }

    public func recordFocus(session: FocusSession) throws {
        var state = try store.load()
        state.focusSessions.removeAll { $0.id == session.id }
        state.focusSessions.append(session)

        if session.outcome == .completed, let ended = session.endedAt {
            let key = day(for: ended)
            var record = state.days.first { $0.date == key } ?? DayRecord(date: key)
            record.focusSessionsCompleted += 1
            record.focusMinutes += session.elapsedMinutes(now: ended)
            record.hasSignal = true
            upsert(record, in: &state)
        }
        try store.save(state)
    }

    // MARK: Rollover

    /// Commits every finished day that has not been committed yet.
    ///
    /// Idempotent and catch-up safe: if the app was not opened for a week, this walks
    /// forward day by day so streaks and the comeback bonus resolve in the right order.
    @discardableResult
    public func rollover(now: Date = Date()) throws -> [HealthEntry] {
        var state = try store.load()
        let today = day(for: now)

        let pending = state.days
            .filter { $0.date < today }
            .filter { record in !state.entries.contains { $0.date == record.date } }
            .sorted { $0.date < $1.date }

        guard !pending.isEmpty else { return [] }

        var committed: [HealthEntry] = []
        for record in pending {
            let context = EvaluationContext(
                currentHealth: state.health,
                currentStage: state.stage,
                streakBefore: state.streak
            )
            let entry = engine.evaluate(day: record, context: context)
            state.health = entry.healthAfter
            state.stage = entry.stageAfter
            state.streak = entry.streakAfter
            state.entries.append(entry)
            committed.append(entry)
        }

        state.lastRollover = today
        try store.save(state)
        return committed
    }

    /// Today's live, uncommitted delta, so the character reacts during the day.
    public func provisionalToday(now: Date = Date()) throws -> (record: DayRecord, delta: Double) {
        let state = try store.load()
        let key = day(for: now)
        let record = state.days.first { $0.date == key } ?? DayRecord(date: key, hasSignal: false)
        let context = EvaluationContext(
            currentHealth: state.health,
            currentStage: state.stage,
            streakBefore: state.streak
        )
        return (record, engine.provisionalDelta(day: record, context: context))
    }

    // MARK: Trend

    /// Distracting minutes over the last `days` days versus the `days` before that.
    /// Blind days are excluded from both sides rather than counted as zero.
    public func improvement(days window: Int = 7, now: Date = Date()) throws -> Double? {
        let state = try store.load()
        let today = day(for: now)
        func total(from lower: Int, to upper: Int) -> (sum: Int, count: Int) {
            let slice = state.days.filter { record in
                guard record.hasSignal,
                      let offset = calendar.dateComponents([.day], from: record.date, to: today).day
                else { return false }
                return offset >= lower && offset < upper
            }
            return (slice.reduce(0) { $0 + $1.distractingMinutes }, slice.count)
        }
        let recent = total(from: 0, to: window)
        let prior = total(from: window, to: window * 2)
        guard recent.count > 0, prior.count > 0 else { return nil }
        let a = Double(recent.sum) / Double(recent.count)
        let b = Double(prior.sum) / Double(prior.count)
        guard b > 0 else { return nil }
        return (a - b) / b   // negative means improvement
    }

    private func upsert(_ record: DayRecord, in state: inout LedgerState) {
        if let index = state.days.firstIndex(where: { $0.date == record.date }) {
            state.days[index] = record
        } else {
            state.days.append(record)
            state.days.sort { $0.date < $1.date }
        }
    }
}
