import Foundation

/// Everything a gem is allowed to look at.
///
/// Deliberately a snapshot of the ledger and nothing else. A gem cannot consult a random
/// number, a server, or the clock beyond `now` — so a user who asks "why did that
/// unlock?" always gets an answer that points at their own days.
public struct GemContext: Sendable, Equatable {
    /// Completed days, oldest first. Today is not in here until it rolls over.
    public var days: [DayRecord]
    public var entries: [HealthEntry]
    public var streak: Int
    public var health: Double
    public var stage: BrainStage
    public var now: Date

    public init(
        days: [DayRecord],
        entries: [HealthEntry],
        streak: Int,
        health: Double,
        stage: BrainStage,
        now: Date = Date()
    ) {
        self.days = days
        self.entries = entries
        self.streak = streak
        self.health = health
        self.stage = stage
        self.now = now
    }

    // MARK: Derived

    /// Days with a real signal. Blind days are excluded from every gem, because a gem
    /// awarded for a day we did not observe would be a lie (docs/08-DECISIONS.md D8).
    public var observedDays: [DayRecord] { days.filter(\.hasSignal) }

    public var totalFocusMinutes: Int { days.reduce(0) { $0 + $1.focusMinutes } }

    public var honoredWindows: Int { days.reduce(0) { $0 + $1.scheduledWindowsHonored } }

    /// The longest run of consecutive observed days with no override taken.
    public var longestCleanRun: Int {
        var best = 0
        var run = 0
        for day in days {
            if day.hasSignal && day.overridesTaken == 0 {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// The longest run of consecutive days that produced any signal at all.
    public var longestObservedRun: Int {
        var best = 0
        var run = 0
        for day in days {
            if day.hasSignal {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// Health movement across the last `window` recorded entries.
    public func healthChange(overLast window: Int) -> Double? {
        guard entries.count >= 2 else { return nil }
        let slice = entries.suffix(window)
        guard let first = slice.first, let last = slice.last else { return nil }
        return last.healthAfter - first.healthBefore
    }
}

/// One unlockable.
///
/// Opal calls these Focus Gems and ties them to milestones. Ours are the same idea with
/// one rule added: **every gem's `requirement` string describes its `test` exactly.**
/// If the text and the predicate ever disagree, the text is the bug — a reward whose
/// condition you cannot read is a slot machine.
public struct Gem: Sendable, Identifiable {
    public let id: String
    public let title: String
    /// Shown verbatim in the UI, locked or not. No hidden gems.
    public let requirement: String
    public let test: @Sendable (GemContext) -> Bool

    public init(
        id: String,
        title: String,
        requirement: String,
        test: @escaping @Sendable (GemContext) -> Bool
    ) {
        self.id = id
        self.title = title
        self.requirement = requirement
        self.test = test
    }
}

/// The twelve. Ordered roughly by how early they land, which is also the display order.
public enum GemCatalog {
    public static let all: [Gem] = [
        Gem(
            id: "first-signal",
            title: "First Reading",
            requirement: "One day measured end to end."
        ) { $0.observedDays.count >= 1 },

        Gem(
            id: "under-half",
            title: "Half Rations",
            requirement: "A day spent under half your budget."
        ) { context in
            context.observedDays.contains { ($0.budgetRatio ?? .infinity) <= 0.5 }
        },

        Gem(
            id: "quiet-day",
            title: "Nothing To Block",
            requirement: "A green day where no shield ever had to appear."
        ) { context in
            context.observedDays.contains { $0.isGreen && $0.shieldsShown == 0 }
        },

        Gem(
            id: "streak-7",
            title: "Seven",
            requirement: "Seven green days in a row."
        ) { $0.streak >= 7 },

        Gem(
            id: "streak-30",
            title: "Thirty",
            requirement: "Thirty green days in a row."
        ) { $0.streak >= 30 },

        Gem(
            id: "focus-600",
            title: "Ten Hours",
            requirement: "Ten hours inside focus sessions, all time."
        ) { $0.totalFocusMinutes >= 600 },

        Gem(
            id: "clean-week",
            title: "No Way Through",
            requirement: "Seven days running without taking a single override."
        ) { $0.longestCleanRun >= 7 },

        Gem(
            id: "honest-week",
            title: "Nothing Missed",
            requirement: "Seven days running where the monitor never went blind."
        ) { $0.longestObservedRun >= 7 },

        Gem(
            id: "windows-10",
            title: "Kept Ten",
            requirement: "Ten scheduled windows honoured."
        ) { $0.honoredWindows >= 10 },

        Gem(
            id: "climb-20",
            title: "Twenty Up",
            requirement: "Health up twenty points across seven days."
        ) { ($0.healthChange(overLast: 7) ?? 0) >= 20 },

        Gem(
            id: "left-mush",
            title: "Out Of The Mush",
            requirement: "Climbed out of Mush after falling into it."
        ) { context in
            context.entries.contains { $0.stageBefore == .mush && $0.stageAfter > .mush }
        },

        Gem(
            id: "crisp-100",
            title: "Solid",
            requirement: "Health at one hundred."
        ) { $0.health >= 100 }
    ]

    public static func gem(id: String) -> Gem? { all.first { $0.id == id } }
}

/// Which gems are unlocked, and which just became unlocked.
///
/// Persisted as ids, never as booleans in order — so adding a gem to the catalogue in the
/// middle cannot silently relabel someone's collection.
public struct GemState: Codable, Sendable, Equatable {
    public var unlocked: Set<String>
    /// When each was unlocked. Used for the "earned on" line and for ordering the shelf.
    public var unlockedAt: [String: Date]

    public init(unlocked: Set<String> = [], unlockedAt: [String: Date] = [:]) {
        self.unlocked = unlocked
        self.unlockedAt = unlockedAt
    }
}

public enum GemEvaluator {
    /// Test every locked gem. Returns the ones that fired, in catalogue order.
    ///
    /// Gems never re-lock. A gem is a record of something that happened, and it happened
    /// whatever you do next — taking it away would make it a punishment with extra steps.
    @discardableResult
    public static func evaluate(_ context: GemContext, state: inout GemState) -> [Gem] {
        var newly: [Gem] = []
        for gem in GemCatalog.all where !state.unlocked.contains(gem.id) {
            guard gem.test(context) else { continue }
            state.unlocked.insert(gem.id)
            state.unlockedAt[gem.id] = context.now
            newly.append(gem)
        }
        return newly
    }
}
