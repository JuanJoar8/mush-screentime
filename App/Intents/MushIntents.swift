import AppIntents
import Foundation
import MushKit
import WidgetKit

/// Shortcuts entry points.
///
/// Three jobs in one file, because they are the same mechanism:
///
/// 1. **Opal parity** — "Focus Mode integration". Start and end a session from a
///    Shortcut, a Focus filter, or the Action button.
/// 2. **Path B measurement** — with no Family Controls entitlement, a pair of personal
///    automations ("when Instagram is opened / closed") is the only way we can observe
///    usage at all (docs/09-PATH-B-NO-ENTITLEMENT.md).
/// 3. **Path B intervention** — `InterruptIntent`, the one that foregrounds us.
///
/// Everything except `InterruptIntent` sets `openAppWhenRun = false`. An automation that
/// yanked you into our app every time it merely *measured* something would be a worse
/// interruption than the one it is measuring. The interrupt intent is the deliberate
/// exception: being seen is its entire job.

// MARK: - Measurement

struct LogAppOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Log app opened"
    static let description = IntentDescription(
        "Records that a watched app was opened. Used by the automations Mush sets up.",
        categoryName: "Measurement"
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "App")
    var appKey: String

    init() {}
    init(appKey: String) { self.appKey = appKey }

    func perform() async throws -> some IntentResult {
        try PathBRecorder.shared.open(appKey: appKey, at: Date())
        return .result()
    }
}

struct LogAppCloseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log app closed"
    static let description = IntentDescription(
        "Closes the open session for a watched app. Pairs with Log app opened.",
        categoryName: "Measurement"
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "App")
    var appKey: String

    init() {}
    init(appKey: String) { self.appKey = appKey }

    func perform() async throws -> some IntentResult {
        try PathBRecorder.shared.close(appKey: appKey, at: Date())
        return .result()
    }
}

// MARK: - Interruption

/// The one intent here that deliberately opens the app.
///
/// This is Path B's whole intervention, and the mechanism is `one sec`'s: a Shortcuts
/// personal automation on "App → Instagram → Is Opened", with *Ask Before Running* off,
/// running this. iOS foregrounds us, the user sees a pause instead of the feed, and
/// decides again.
///
/// It is friction, not a block. Nothing here prevents the app from opening, and the
/// screen it presents says so (`docs/09-PATH-B-NO-ENTITLEMENT.md`).
struct InterruptIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause before this app"
    static let description = IntentDescription(
        "Opens Mush with a short pause, so you decide again before the feed loads.",
        categoryName: "Interruption"
    )
    /// The exception. Every other intent in this file stays in the background on purpose;
    /// this one has to foreground us, because being seen *is* the intervention.
    static let openAppWhenRun = true
    static let isDiscoverable = true

    @Parameter(title: "App name")
    var appName: String

    init() {}
    init(appName: String) { self.appName = appName }

    func perform() async throws -> some IntentResult {
        let key = appName.lowercased().replacingOccurrences(of: " ", with: "-")
        InterruptionInbox().post(PendingInterruption(appKey: key, appName: appName))
        try PathBRecorder.shared.open(appKey: key, at: Date())
        return .result()
    }
}

// MARK: - Focus

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a focus session"
    static let description = IntentDescription(
        "Starts a focus session for a number of minutes.",
        categoryName: "Focus"
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Minutes", default: 25, inclusiveRange: (5, 180))
    var minutes: Int

    init() {}
    init(minutes: Int) { self.minutes = minutes }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let session = FocusSession(kind: .focus, startedAt: Date(), plannedMinutes: minutes)
        try PathBRecorder.shared.startFocus(session)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "\(minutes) minutes. Blocks lift when it ends.")
    }
}

struct EndFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "End the focus session"
    static let description = IntentDescription(
        "Ends the running focus session early. It is recorded as abandoned.",
        categoryName: "Focus"
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ended = try PathBRecorder.shared.endFocus(at: Date())
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: ended ? "Ended. It counts as abandoned." : "Nothing was running.")
    }
}

// MARK: - Shortcut suggestions

struct MushShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: ["Start a \(.applicationName) session"],
            shortTitle: "Start focus",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: EndFocusIntent(),
            phrases: ["End my \(.applicationName) session"],
            shortTitle: "End focus",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: InterruptIntent(),
            phrases: ["Pause with \(.applicationName)"],
            shortTitle: "Pause",
            systemImageName: "hand.raised"
        )
    }
}

// MARK: - The recorder

/// Writes what the intents observe into the App Group, and keeps the widget honest.
///
/// Intents run in a short-lived process with no shared state, so every call loads,
/// mutates and saves. That is fine at this volume — a handful of writes a day — and it
/// removes any question of two processes holding divergent copies.
final class PathBRecorder: @unchecked Sendable {
    static let shared = PathBRecorder()

    private let store: LedgerStoring?
    private let snapshots = WidgetSnapshotStore()
    private let lock = NSLock()

    private init() {
        store = try? FileLedgerStore()
    }

    func open(appKey: String, at date: Date) throws {
        try mutate { state in
            // An unclosed session for the same app means the close automation never ran.
            // Leave it open: `SessionAssembler` already treats that as partial rather
            // than guessing a duration.
            state.pathBSessions.append(AppSession(appKey: appKey, openedAt: date))
        }
    }

    func close(appKey: String, at date: Date) throws {
        try mutate { state in
            guard let index = state.pathBSessions.lastIndex(where: {
                $0.appKey == appKey && $0.isOpen
            }) else { return }
            state.pathBSessions[index].closedAt = date
        }
    }

    func startFocus(_ session: FocusSession) throws {
        try mutate { state in
            state.focusSessions.append(session)
        }
    }

    @discardableResult
    func endFocus(at date: Date) throws -> Bool {
        var didEnd = false
        try mutate { state in
            guard let index = state.focusSessions.lastIndex(where: { $0.outcome == .running })
            else { return }
            state.focusSessions[index].endedAt = date
            state.focusSessions[index].outcome = .abandoned
            didEnd = true
        }
        return didEnd
    }

    private func mutate(_ body: (inout LedgerState) -> Void) throws {
        guard let store else { return }
        lock.lock()
        defer { lock.unlock() }
        var state = try store.load()
        body(&state)
        try store.save(state)
        refreshSnapshot(from: state)
    }

    private func refreshSnapshot(from state: LedgerState) {
        let today = state.days.last ?? DayRecord(date: Calendar.current.startOfDay(for: Date()))
        let running = state.focusSessions.last { $0.outcome == .running }
        let endsAt = running.map {
            $0.startedAt.addingTimeInterval(Double($0.plannedMinutes) * 60)
        }
        snapshots.write(WidgetSnapshot(state: state, today: today, focusEndsAt: endsAt))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
