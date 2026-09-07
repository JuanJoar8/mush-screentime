import Foundation

/// Seven days, the seven before them, and the single thing that moved the number most.
///
/// Opal ships a weekly report; so does almost everything in this category. The part
/// almost nobody ships is the refusal: **a week containing blind days cannot be compared
/// to another week.** We know how many days we failed to observe, so we say the
/// comparison is unavailable rather than quietly reporting a drop that is really just a
/// monitor that never woke (docs/08-DECISIONS.md D8).
public struct WeeklyDigest: Sendable, Equatable {
    /// Start of the first day in the reported window.
    public var start: Date
    /// Start of the day *after* the window. Half-open, so arithmetic stays honest.
    public var end: Date

    public var distractingMinutes: Int
    public var priorDistractingMinutes: Int
    public var greenDays: Int
    public var observedDays: Int
    public var priorObservedDays: Int
    public var focusMinutes: Int
    public var focusSessions: Int
    public var overridesTaken: Int
    public var shieldsShown: Int
    public var windowsHonored: Int
    public var windowsExpected: Int

    public var healthStart: Double
    public var healthEnd: Double

    /// The contribution kind that moved health most across the week, summed over days.
    /// Nil when nothing was evaluated.
    public var biggestMover: Contribution?

    public var blindDays: Int { 7 - observedDays }
    public var priorBlindDays: Int { 7 - priorObservedDays }
    public var healthDelta: Double { healthEnd - healthStart }

    /// Minutes vs the prior week. Only meaningful when `isComparable`.
    public var minutesDelta: Int { distractingMinutes - priorDistractingMinutes }

    /// Both weeks need at least five observed days before a comparison means anything.
    ///
    /// Five, not seven: demanding a perfect fortnight would mean almost never showing a
    /// comparison, and two missed days out of seven still leaves a usable trend as long
    /// as the UI says how many days were missed. It always does.
    public var isComparable: Bool { observedDays >= 5 && priorObservedDays >= 5 }

    /// One sentence, in the product's voice. Never a percentage we cannot support.
    public var headline: String {
        guard isComparable else {
            return "Not comparable — \(blindDays + priorBlindDays) days went unmeasured across the two weeks."
        }
        if minutesDelta == 0 { return "Exactly level with last week." }
        let direction = minutesDelta < 0 ? "less" : "more"
        return "\(abs(minutesDelta)) minutes \(direction) than the week before."
    }
}

public enum WeeklyDigestBuilder {
    /// Build the digest for the seven days ending on the last completed day.
    ///
    /// `days` and `entries` are the ledger's own arrays, oldest first. Days that are not
    /// in either window are ignored; missing days are counted as blind rather than
    /// skipped, which is why the window is derived from the calendar and not from the
    /// array's length.
    public static func build(
        days: [DayRecord],
        entries: [HealthEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyDigest {
        let today = calendar.startOfDay(for: now)
        // The window ends at the start of today: today is still in progress and would
        // report as a partial day pretending to be a whole one.
        let end = today
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let priorStart = calendar.date(byAdding: .day, value: -14, to: end) ?? end

        let inWindow = days.filter { $0.date >= start && $0.date < end }
        let inPrior = days.filter { $0.date >= priorStart && $0.date < start }
        let windowEntries = entries.filter { $0.date >= start && $0.date < end }

        let observed = inWindow.filter(\.hasSignal)
        let priorObserved = inPrior.filter(\.hasSignal)

        return WeeklyDigest(
            start: start,
            end: end,
            distractingMinutes: observed.reduce(0) { $0 + $1.distractingMinutes },
            priorDistractingMinutes: priorObserved.reduce(0) { $0 + $1.distractingMinutes },
            greenDays: inWindow.filter(\.isGreen).count,
            observedDays: observed.count,
            priorObservedDays: priorObserved.count,
            focusMinutes: inWindow.reduce(0) { $0 + $1.focusMinutes },
            focusSessions: inWindow.reduce(0) { $0 + $1.focusSessionsCompleted },
            overridesTaken: inWindow.reduce(0) { $0 + $1.overridesTaken },
            shieldsShown: inWindow.reduce(0) { $0 + $1.shieldsShown },
            windowsHonored: inWindow.reduce(0) { $0 + $1.scheduledWindowsHonored },
            windowsExpected: inWindow.reduce(0) { $0 + $1.scheduledWindowsExpected },
            healthStart: windowEntries.first?.healthBefore ?? 0,
            healthEnd: windowEntries.last?.healthAfter ?? 0,
            biggestMover: biggestMover(in: windowEntries)
        )
    }

    /// Sum every contribution by kind, then take the one with the largest magnitude.
    ///
    /// Magnitude, not value: the most useful sentence of the week is as often "overrides
    /// cost you 9 points" as "focus earned you 12".
    static func biggestMover(in entries: [HealthEntry]) -> Contribution? {
        var totals: [Contribution.Kind: Double] = [:]
        for entry in entries {
            for contribution in entry.contributions {
                totals[contribution.kind, default: 0] += contribution.value
            }
        }
        guard let (kind, value) = totals.max(by: { abs($0.value) < abs($1.value) }),
              value != 0
        else { return nil }
        return Contribution(kind: kind, value: value, reason: weeklyReason(for: kind, value: value))
    }

    private static func weeklyReason(for kind: Contribution.Kind, value: Double) -> String {
        let points = abs(value).rounded()
        let amount = "\(Int(points)) point\(points == 1 ? "" : "s")"
        switch kind {
        case .budget:
            return value >= 0
                ? "Staying under budget earned \(amount)"
                : "Going over budget cost \(amount)"
        case .focus: return "Focus sessions earned \(amount)"
        case .overrides: return "Overrides cost \(amount)"
        case .schedule: return "Keeping scheduled windows earned \(amount)"
        case .streak: return "The streak earned \(amount)"
        case .comeback: return "Climbing back earned \(amount)"
        }
    }
}
