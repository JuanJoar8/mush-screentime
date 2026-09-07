import Foundation

/// Everything the widget is allowed to know, in one small value.
///
/// The widget process gets a few milliseconds and a tight memory budget, so it does not
/// open the ledger, replay the engine, or decode a year of days. The app and the monitor
/// extension write this snapshot; the widget only reads it.
///
/// `capturedAt` is not decoration. `WidgetCenter.reloadAllTimelines()` from an extension
/// is budgeted and can be deferred, so the widget must be able to say *when* this was
/// true rather than implying it is live.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public var health: Double
    public var stage: BrainStage
    public var distractingMinutes: Int
    public var budgetMinutes: Int
    public var streak: Int
    /// False when the monitor produced nothing today. The widget draws hollow, not zero.
    public var hasSignal: Bool
    /// True when we know today's figure is a floor — Path B with an unclosed session.
    public var isPartial: Bool
    /// Set while a focus session is running, so the widget can show the countdown
    /// without the app being awake.
    public var focusEndsAt: Date?
    public var capturedAt: Date

    public init(
        health: Double,
        stage: BrainStage,
        distractingMinutes: Int,
        budgetMinutes: Int,
        streak: Int,
        hasSignal: Bool,
        isPartial: Bool = false,
        focusEndsAt: Date? = nil,
        capturedAt: Date = Date()
    ) {
        self.health = health
        self.stage = stage
        self.distractingMinutes = distractingMinutes
        self.budgetMinutes = budgetMinutes
        self.streak = streak
        self.hasSignal = hasSignal
        self.isPartial = isPartial
        self.focusEndsAt = focusEndsAt
        self.capturedAt = capturedAt
    }

    public var budgetRatio: Double? {
        guard budgetMinutes > 0 else { return nil }
        return Double(distractingMinutes) / Double(budgetMinutes)
    }

    public var minutesLeft: Int { max(0, budgetMinutes - distractingMinutes) }

    public func isFocusRunning(at date: Date) -> Bool {
        guard let focusEndsAt else { return false }
        return focusEndsAt > date
    }

    /// How the widget labels its own figure.
    ///
    /// A widget refreshed an hour ago that says "23 min" is claiming something false. It
    /// either says the number is current or it timestamps it — never neither.
    public func freshness(at date: Date, tolerance: TimeInterval = 15 * 60) -> String? {
        let age = date.timeIntervalSince(capturedAt)
        guard age > tolerance else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "as of \(formatter.string(from: capturedAt))"
    }

    /// Shown when there is nothing to show — a fresh install, or a blind day.
    public static let placeholder = WidgetSnapshot(
        health: 70,
        stage: .foggy,
        distractingMinutes: 0,
        budgetMinutes: 60,
        streak: 0,
        hasSignal: false,
        capturedAt: .distantPast
    )
}

/// Reads and writes the snapshot in the App Group.
///
/// `UserDefaults` rather than a file: the widget's read has to be cheap and cannot fail
/// halfway through a timeline build, and the payload is a few dozen bytes.
public struct WidgetSnapshotStore: Sendable {
    public static let key = "mush.widget.snapshot"

    private let suiteName: String

    public init(appGroup: String = MushIdentifiers.appGroup) {
        self.suiteName = appGroup
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    public func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: Self.key)
    }

    /// Returns the placeholder rather than nil. A widget has to draw something, and a
    /// widget that draws an error is worse than one that draws a known-stale figure.
    public func read() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: Self.key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}

public extension WidgetSnapshot {
    /// Build from ledger state plus today's provisional record.
    init(state: LedgerState, today: DayRecord, focusEndsAt: Date? = nil, now: Date = Date()) {
        self.init(
            health: state.health,
            stage: state.stage,
            distractingMinutes: today.distractingMinutes,
            budgetMinutes: today.budgetMinutes,
            streak: state.streak,
            hasSignal: today.hasSignal,
            isPartial: today.isPartial,
            focusEndsAt: focusEndsAt,
            capturedAt: now
        )
    }
}
