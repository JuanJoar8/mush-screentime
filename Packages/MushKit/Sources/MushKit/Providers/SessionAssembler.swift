import Foundation

/// Path B measurement: usage assembled from Shortcuts automation events instead of
/// `DeviceActivityEvent` thresholds. See `docs/09-PATH-B-NO-ENTITLEMENT.md`.
///
/// Two personal automations per watched app — "is opened" and "is closed" — each running
/// a background `AppIntent`. The pair gives a real session with a real duration, and
/// needs no entitlement of any kind.
public struct AppSession: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Our own stable key for the app, e.g. "instagram". Path B never sees an opaque
    /// token, so unlike Path A the identifier is ours and cannot rotate.
    public var appKey: String
    public var openedAt: Date
    public var closedAt: Date?
    /// An intervention screen was presented for this open.
    public var wasInterrupted: Bool
    /// The user tapped past the intervention and continued into the app.
    public var dismissedIntervention: Bool

    public init(
        id: UUID = UUID(),
        appKey: String,
        openedAt: Date,
        closedAt: Date? = nil,
        wasInterrupted: Bool = false,
        dismissedIntervention: Bool = false
    ) {
        self.id = id
        self.appKey = appKey
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.wasInterrupted = wasInterrupted
        self.dismissedIntervention = dismissedIntervention
    }

    public var isOpen: Bool { closedAt == nil }
}

/// Turns raw session events into a `DayRecord`, applying the same rule the ladder model
/// uses: **never invent a number we did not observe.**
public struct SessionAssembler: Sendable {
    /// A single session longer than this is treated as a missed close rather than as a
    /// two-hour scroll. Suspicious, so it marks the day partial instead of contributing.
    public let ceilingMinutes: Int
    public let calendar: Calendar

    public init(ceilingMinutes: Int = 120, calendar: Calendar = .current) {
        self.ceilingMinutes = ceilingMinutes
        self.calendar = calendar
    }

    public struct Assembly: Sendable, Equatable {
        public var minutes: Int
        public var opens: Int
        public var isPartial: Bool
        public var hasSignal: Bool
    }

    public func assemble(
        sessions: [AppSession],
        on date: Date,
        now: Date = Date()
    ) -> Assembly {
        let day = calendar.startOfDay(for: date)
        let todays = sessions.filter { calendar.startOfDay(for: $0.openedAt) == day }

        guard !todays.isEmpty else {
            return Assembly(minutes: 0, opens: 0, isPartial: false, hasSignal: false)
        }

        var seconds: TimeInterval = 0
        var partial = false
        let ceiling = TimeInterval(ceilingMinutes * 60)

        for session in todays {
            if let closed = session.closedAt {
                let duration = closed.timeIntervalSince(session.openedAt)
                if duration < 0 {
                    // Clock moved, or events arrived out of order. Do not guess.
                    partial = true
                } else if duration > ceiling {
                    // Almost certainly a missed close that got paired with a much later
                    // one. Counting it would fabricate hours of usage.
                    partial = true
                } else {
                    seconds += duration
                }
            } else {
                let elapsed = now.timeIntervalSince(session.openedAt)
                if elapsed <= ceiling {
                    // Still open right now. Legitimate to count so far.
                    seconds += max(0, elapsed)
                } else {
                    // Opened long ago, never closed. The close event was lost.
                    partial = true
                }
            }
        }

        return Assembly(
            minutes: Int(seconds / 60),
            opens: todays.count,
            isPartial: partial,
            hasSignal: true
        )
    }

    /// Builds the day record the rest of the product already understands. Everything
    /// downstream — brain health, streaks, statistics — is unchanged by the switch of
    /// data source.
    public func dayRecord(
        sessions: [AppSession],
        on date: Date,
        budgetMinutes: Int,
        now: Date = Date()
    ) -> DayRecord {
        let assembly = assemble(sessions: sessions, on: date, now: now)
        let todays = sessions.filter {
            calendar.startOfDay(for: $0.openedAt) == calendar.startOfDay(for: date)
        }

        var record = DayRecord(date: calendar.startOfDay(for: date), budgetMinutes: budgetMinutes)
        record.distractingMinutes = assembly.minutes
        record.hasSignal = assembly.hasSignal
        record.isPartial = assembly.isPartial
        // Under Path B an "intervention shown" is the equivalent of a shield appearing,
        // and pushing past it is the equivalent of an override.
        record.shieldsShown = todays.filter(\.wasInterrupted).count
        record.overridesTaken = todays.filter(\.dismissedIntervention).count
        return record
    }
}
