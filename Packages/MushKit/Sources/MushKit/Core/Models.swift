import Foundation

// MARK: - The day record

/// Everything we are allowed to know about one day, from our own ledger.
///
/// Note what is *absent*: total device screen time, per-app breakdowns, pickups. Those
/// exist only inside the report extension and can never reach this struct
/// (docs/01-FEASIBILITY.md section 3). If you are tempted to add them here, you are
/// about to design something impossible.
public struct DayRecord: Codable, Sendable, Equatable, Identifiable {
    /// Start of day, in the user's calendar.
    public var date: Date
    public var id: Date { date }

    /// Minutes on watched apps, accumulated from accepted ladder rungs. Quantised to
    /// the ladder step, so this is a floor, not an exact figure.
    public var distractingMinutes: Int
    /// The budget in force that day. Stored per-day so history stays meaningful after
    /// the user changes their budget.
    public var budgetMinutes: Int

    public var focusSessionsCompleted: Int
    public var focusMinutes: Int
    public var overridesTaken: Int
    public var shieldsShown: Int
    public var grantsIssued: Int

    public var scheduledWindowsExpected: Int
    public var scheduledWindowsHonored: Int

    /// False when the monitor extension produced nothing at all that day — permission
    /// revoked, device off, or the extension never woke. Such a day scores zero and is
    /// never counted as green (docs/08-DECISIONS.md D8).
    public var hasSignal: Bool

    /// True when we saw *some* activity but know the picture is incomplete — under
    /// Path B, an app that was opened and never reported closed. The day still scores,
    /// but the UI marks it, because the real number can only be higher than what we show.
    public var isPartial: Bool

    public init(
        date: Date,
        distractingMinutes: Int = 0,
        budgetMinutes: Int = 60,
        focusSessionsCompleted: Int = 0,
        focusMinutes: Int = 0,
        overridesTaken: Int = 0,
        shieldsShown: Int = 0,
        grantsIssued: Int = 0,
        scheduledWindowsExpected: Int = 0,
        scheduledWindowsHonored: Int = 0,
        hasSignal: Bool = true,
        isPartial: Bool = false
    ) {
        self.date = date
        self.distractingMinutes = distractingMinutes
        self.budgetMinutes = budgetMinutes
        self.focusSessionsCompleted = focusSessionsCompleted
        self.focusMinutes = focusMinutes
        self.overridesTaken = overridesTaken
        self.shieldsShown = shieldsShown
        self.grantsIssued = grantsIssued
        self.scheduledWindowsExpected = scheduledWindowsExpected
        self.scheduledWindowsHonored = scheduledWindowsHonored
        self.hasSignal = hasSignal
        self.isPartial = isPartial
    }

    /// `distractingMinutes / budgetMinutes`. Nil when there is no usable budget, which
    /// the engine treats as "cannot score" rather than as "scored zero".
    public var budgetRatio: Double? {
        guard budgetMinutes > 0 else { return nil }
        return Double(distractingMinutes) / Double(budgetMinutes)
    }

    /// A green day: we had a signal, and usage stayed at or under budget.
    public var isGreen: Bool {
        guard hasSignal, let r = budgetRatio else { return false }
        return r <= 1.0
    }

    public var minutesOverBudget: Int { max(0, distractingMinutes - budgetMinutes) }
}

// MARK: - Strictness

/// How hard it is to get past a shield.
///
/// None of these is a lock. iOS gives third-party Screen Time permission no passcode
/// protection (FB18794535) — the user can revoke it in Settings with one toggle. The UI
/// says so at the point of choosing, because promising otherwise would be a lie.
public enum Strictness: String, Codable, Sendable, CaseIterable, Identifiable {
    case gentle, standard, strict, sealed
    public var id: String { rawValue }

    /// Does the shield offer an escape hatch at all?
    public var allowsOverride: Bool {
        switch self {
        case .gentle, .standard: true
        case .strict, .sealed: false
        }
    }

    /// Must the user complete an intervention in our app before the grant is issued?
    public var requiresInterventionBeforeGrant: Bool { self == .standard }

    /// Usage-minutes granted by the escape hatch. Usage time, not wall clock
    /// (docs/08-DECISIONS.md D5).
    public var grantMinutes: Int {
        switch self {
        case .gentle: 5
        case .standard: 5
        case .strict, .sealed: 0
        }
    }

    public var title: String {
        switch self {
        case .gentle: "Gentle"
        case .standard: "Standard"
        case .strict: "Strict"
        case .sealed: "Sealed"
        }
    }

    public var explanation: String {
        switch self {
        case .gentle: "One tap gets you five more minutes. It still counts against you."
        case .standard: "You can get through, but you have to do something first."
        case .strict: "No way through until the window ends."
        case .sealed: "Strict, and our own unblock controls go behind a delay."
        }
    }
}

// MARK: - Rules and windows

/// A recurring block window: bedtime, mornings, work hours.
public struct ScheduleWindow: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// Minutes from midnight, in the user's calendar.
    public var startMinute: Int
    public var endMinute: Int
    /// 1 = Sunday, matching `Calendar.component(.weekday:)`.
    public var weekdays: Set<Int>
    public var strictness: Strictness
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        startMinute: Int,
        endMinute: Int,
        weekdays: Set<Int> = Set(1...7),
        strictness: Strictness = .standard,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.strictness = strictness
        self.isEnabled = isEnabled
    }

    /// True when the window wraps past midnight (a bedtime window usually does).
    public var crossesMidnight: Bool { endMinute <= startMinute }

    /// Duration in minutes, accounting for the midnight wrap.
    public var durationMinutes: Int {
        crossesMidnight ? (1440 - startMinute) + endMinute : endMinute - startMinute
    }

    /// `DeviceActivitySchedule` refuses intervals under 15 minutes
    /// (docs/01-FEASIBILITY.md L3), so a window shorter than that cannot be scheduled.
    public var isSchedulable: Bool { durationMinutes >= 15 }

    public func occursOn(weekday: Int) -> Bool { isEnabled && weekdays.contains(weekday) }
}

/// An active grant of temporary access, issued from a shield.
public struct Grant: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var storeName: String
    public var issuedAt: Date
    /// Usage minutes, not wall-clock minutes.
    public var usageMinutes: Int

    public init(id: UUID = UUID(), storeName: String, issuedAt: Date, usageMinutes: Int) {
        self.id = id
        self.storeName = storeName
        self.issuedAt = issuedAt
        self.usageMinutes = usageMinutes
    }
}

// MARK: - Focus

public struct FocusSession: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable { case focus, pomodoro, breakInterval }
    public enum Outcome: String, Codable, Sendable { case running, completed, abandoned }

    public var id: UUID
    public var kind: Kind
    public var startedAt: Date
    public var plannedMinutes: Int
    public var endedAt: Date?
    public var outcome: Outcome

    public init(
        id: UUID = UUID(),
        kind: Kind = .focus,
        startedAt: Date,
        plannedMinutes: Int,
        endedAt: Date? = nil,
        outcome: Outcome = .running
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.plannedMinutes = plannedMinutes
        self.endedAt = endedAt
        self.outcome = outcome
    }

    public func elapsedMinutes(now: Date) -> Int {
        Int((endedAt ?? now).timeIntervalSince(startedAt) / 60)
    }
}
