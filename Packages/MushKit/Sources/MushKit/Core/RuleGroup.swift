import Foundation

// MARK: - Block mode

/// Blocklist or allowlist. Opal calls the second one "Allow Only".
///
/// This is not a cosmetic flip. `ShieldSettings.ActivityCategoryPolicy.all(except:)` is a
/// real public API, but a `ManagedSettingsStore` **cannot make another store less
/// restrictive**: once any store shields everything, no other store can carve an
/// exception back out. So an allowlist group cannot coexist with the per-concern stores
/// of D4 — while it is on, it owns the whole shield surface (docs/08-DECISIONS.md D16).
public enum BlockMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Shield the selection. Everything else stays open.
    case blocklist
    /// Shield everything *except* the selection.
    case allowlist

    public var id: String { rawValue }

    /// True when turning this group on has to suspend every other group.
    public var isExclusive: Bool { self == .allowlist }

    public var title: String {
        switch self {
        case .blocklist: "Block these"
        case .allowlist: "Only these"
        }
    }

    public var explanation: String {
        switch self {
        case .blocklist: "The apps you pick are shielded. Everything else works."
        case .allowlist:
            "Everything is shielded except the apps you pick. While this is on, your "
            + "other rules are suspended — iOS will not let a second rule reopen "
            + "anything this one closed."
        }
    }
}

// MARK: - Frequency limit

/// A cap on how much of the day an app is allowed to appear in.
///
/// **This is not Opal's Open Limit and must never be labelled one.** iOS publishes no
/// open or pickup count outside the report extension, and the report extension cannot
/// export a number (docs/01-FEASIBILITY.md section 3). Opal's feature has no faithful
/// equivalent under public APIs.
///
/// What we can measure: `DeviceActivitySchedule` has a 15-minute floor (L3) but event
/// thresholds do not, so a repeating quarter-hour schedule carrying a one-minute
/// threshold fires at most once per quarter-hour. Count the distinct quarter-hours that
/// produced a firing and you get **how many 15-minute slices of the day had this app in
/// them** — presence across the day, not opens, not sessions.
///
/// It is a floor: a quarter-hour of use that never crosses a threshold is not counted.
/// That is the right direction to be wrong in — we can say "at least 9", never "9".
public struct FrequencyLimit: Codable, Sendable, Equatable {
    /// Maximum quarter-hours of the day this app may appear in. 96 quarter-hours in a day.
    public var maxTouchedQuarterHours: Int

    public init(maxTouchedQuarterHours: Int) {
        self.maxTouchedQuarterHours = max(1, min(96, maxTouchedQuarterHours))
    }

    /// Phrasing for the UI. Says what it counts, in the words the counter actually uses.
    public var summary: String {
        let hours = Double(maxTouchedQuarterHours) / 4
        let suffix = hours == 1 ? "hour" : "hours"
        return "\(maxTouchedQuarterHours) quarter-hours a day — \(formatted(hours)) \(suffix) of your day, in pieces"
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2g", value)
    }
}

/// Counts quarter-hours touched, from firings we already collect.
public enum QuarterHourCounter {
    /// Index of the quarter-hour a date falls in, 0...95, in the given calendar.
    public static func bucket(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return min(95, minutes / 15)
    }

    /// Distinct quarter-hours containing at least one firing.
    public static func touched(_ firings: [LadderFiring], calendar: Calendar) -> Set<Int> {
        Set(firings.map { bucket(for: $0.at, calendar: calendar) })
    }

    /// Whether the limit has been reached. Reaching it is what shields the app.
    public static func isExceeded(
        _ firings: [LadderFiring],
        limit: FrequencyLimit,
        calendar: Calendar
    ) -> Bool {
        touched(firings, calendar: calendar).count >= limit.maxTouchedQuarterHours
    }
}

// MARK: - Rule group

/// One independent rule: a selection of apps, and everything that governs them.
///
/// Brainrot calls these "smart schedules"; Opal calls them "Focus Rules" and sells
/// unlimited ones. Same shape either way — a set of apps plus when and how hard.
///
/// `MushKit` never imports `FamilyControls` (docs/03-ARCHITECTURE.md), so the actual
/// `FamilyActivitySelection` lives in the App Group under `selectionKey` and this struct
/// only holds the handle.
public struct RuleGroup: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var mode: BlockMode
    /// Key under which `MushScreenTime` persisted the encoded `FamilyActivitySelection`.
    public var selectionKey: String
    /// Daily allowance in minutes. Zero means no time budget on this group.
    public var budgetMinutes: Int
    public var frequencyLimit: FrequencyLimit?
    public var windows: [ScheduleWindow]
    public var strictness: Strictness
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        mode: BlockMode = .blocklist,
        selectionKey: String,
        budgetMinutes: Int = 60,
        frequencyLimit: FrequencyLimit? = nil,
        windows: [ScheduleWindow] = [],
        strictness: Strictness = .standard,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.selectionKey = selectionKey
        self.budgetMinutes = budgetMinutes
        self.frequencyLimit = frequencyLimit
        self.windows = windows
        self.strictness = strictness
        self.isEnabled = isEnabled
    }

    /// Store name for this group's shields. One store per group, per D4.
    public var storeName: String { "group.\(id.uuidString)" }

    /// True when one of this group's windows covers the given moment.
    public func isInWindow(at date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return windows.contains { window in
            guard window.occursOn(weekday: weekday) else { return false }
            if window.crossesMidnight {
                return minute >= window.startMinute || minute < window.endMinute
            }
            return minute >= window.startMinute && minute < window.endMinute
        }
    }

    /// A group with no windows is always in force; one with windows only inside them.
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        isEnabled && (windows.isEmpty || isInWindow(at: date, calendar: calendar))
    }
}

// MARK: - Rule set

/// Why a group that is switched on is not currently in force.
public enum SuspensionReason: String, Codable, Sendable, Equatable {
    /// An allowlist group is active, and iOS cannot let a second store reopen what it shut.
    case allowlistExclusive
    /// Switched on, but outside all of its windows right now.
    case outsideWindow
}

/// One group that is switched on but not in force, and the reason to show next to it.
public struct Suspension: Sendable, Equatable, Identifiable {
    public var group: RuleGroup
    public var reason: SuspensionReason

    public var id: UUID { group.id }

    public init(group: RuleGroup, reason: SuspensionReason) {
        self.group = group
        self.reason = reason
    }
}

/// The resolved picture: which groups are in force, and why the others are not.
public struct RuleResolution: Sendable, Equatable {
    public var active: [RuleGroup]
    public var suspended: [Suspension]

    public init(active: [RuleGroup], suspended: [Suspension]) {
        self.active = active
        self.suspended = suspended
    }
}

/// All of the user's rules, and the one arbitration rule iOS forces on us.
public struct RuleSet: Codable, Sendable, Equatable {
    public var groups: [RuleGroup]

    public init(groups: [RuleGroup] = []) {
        self.groups = groups
    }

    /// Resolve what is actually in force.
    ///
    /// The whole point of this function is the allowlist rule. `.all(except:)` cannot be
    /// softened by another store, so if an allowlist group is live, running the others
    /// alongside it would put shields on screen that the user's own rules say should not
    /// be there — and no amount of store juggling would remove them. The honest handling
    /// is to suspend them and say so.
    ///
    /// If two allowlist groups are live at once, the **first enabled one in order** wins.
    /// The user orders the list; we do not silently merge two contradictory allowlists.
    public func resolve(at date: Date, calendar: Calendar = .current) -> RuleResolution {
        var active: [RuleGroup] = []
        var suspended: [Suspension] = []

        for group in groups where group.isEnabled {
            if group.isActive(at: date, calendar: calendar) {
                active.append(group)
            } else {
                suspended.append(Suspension(group: group, reason: .outsideWindow))
            }
        }

        guard let exclusive = active.first(where: { $0.mode.isExclusive }) else {
            return RuleResolution(active: active, suspended: suspended)
        }

        for group in active where group.id != exclusive.id {
            suspended.append(Suspension(group: group, reason: .allowlistExclusive))
        }
        return RuleResolution(active: [exclusive], suspended: suspended)
    }

    /// The budget in force right now: the tightest active non-zero budget.
    ///
    /// Tightest rather than summed, because two rules that each allow 30 minutes are two
    /// promises of 30, not one promise of 60.
    public func effectiveBudgetMinutes(at date: Date, calendar: Calendar = .current) -> Int? {
        resolve(at: date, calendar: calendar).active
            .map(\.budgetMinutes)
            .filter { $0 > 0 }
            .min()
    }
}
