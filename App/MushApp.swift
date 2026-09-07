import SwiftUI
import MushKit
import WidgetKit

@main
struct MushApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.bootstrap() }
        }
    }
}

/// What the primary action does right now. Contextual rather than fixed: the button
/// that matters changes with the state of the day.
enum PrimaryActionKind {
    case fixAccess
    case endFocus
    case blockEverything
    case startFocus

    var title: String {
        switch self {
        case .fixAccess: "Fix Screen Time access"
        case .endFocus: "End focus session"
        case .blockEverything: "Block everything for an hour"
        case .startFocus: "Start a focus session"
        }
    }
}

/// How restrictions are actually enforced on this build. Named honestly, because Path A
/// and Path B do genuinely different things (docs/09-PATH-B-NO-ENTITLEMENT.md).
enum Enforcement {
    case shielded       // Path A: the app will not open
    case interrupted    // Path B: friction only
    case simulated      // mock provider

    var label: String {
        switch self {
        case .shielded: "blocking"
        case .interrupted: "interrupting"
        case .simulated: "simulated"
        }
    }

    var tint: Color {
        switch self {
        case .shielded: Token.Color.good
        case .interrupted: Token.Color.warn
        case .simulated: Token.Color.inkDim
        }
    }

    var explanation: String {
        switch self {
        case .shielded:
            "Selected apps will not open. A block screen appears instead."
        case .interrupted:
            "We cannot stop an app from opening without Screen Time access, so we interrupt it instead. You can always continue — this is friction, not a lock."
        case .simulated:
            "Running on synthetic data. Family Controls does not work in the Simulator, so nothing here is enforcing anything."
        }
    }
}

/// Composition root.
///
/// The provider is chosen at launch, never by a user-facing setting. On the Simulator —
/// and on any build without the Family Controls entitlement — the live provider cannot
/// work at all, so the mock is used and the UI says so plainly rather than presenting
/// invented numbers as real.
@Observable
@MainActor
final class AppModel {
    struct Totals {
        var shields = 0
        var overrides = 0
        var focusSessions = 0
        var focusMinutes = 0
        var measuredDays = 0
        var blindDays = 0
    }

    private(set) var provider: any ScreenTimeProviding
    private(set) var ledgerStore: LedgerStoring
    private(set) var ledger: UsageLedger
    private(set) var isMocked: Bool

    private(set) var authorization: MushAuthorizationStatus = .notDetermined
    private(set) var health: Double = 70
    private(set) var stage: BrainStage = .foggy
    private(set) var streak: Int = 0
    private(set) var today: DayRecord?
    private(set) var provisionalDelta: Double = 0
    private(set) var lastEntry: HealthEntry?
    private(set) var history: [DayRecord] = []
    private(set) var improvement: Double?
    private(set) var totals = Totals()
    private(set) var activeFocus: FocusSession?
    private(set) var loadError: String?

    // Gamification. All of it derived from the ledger on every refresh, never stored as a
    // separate score — a second number that could disagree with the first is the thing
    // that makes a points system feel bolted on (docs/02-PRODUCT.md section 2).
    private(set) var rules = RuleSet()
    private(set) var gems = GemState()
    private(set) var newlyUnlocked: [Gem] = []
    private(set) var digest: WeeklyDigest?
    private(set) var milestone: MilestoneCrossing?

    private let milestoneWatcher = MilestoneWatcher()
    private let snapshots = WidgetSnapshotStore()

    var unlockedGems: [Gem] { GemCatalog.all.filter { gems.unlocked.contains($0.id) } }
    var lockedGems: [Gem] { GemCatalog.all.filter { !gems.unlocked.contains($0.id) } }

    var strictness: Strictness = .standard
    var budgetMinutes: Int = 60

    init() {
        let mocked = AppModel.shouldUseMock
        self.isMocked = mocked
        let store = InMemoryLedgerStore()
        self.ledgerStore = store
        self.ledger = UsageLedger(store: store)
        self.provider = MockScreenTimeProvider(status: mocked ? .approved : .unavailable)
    }

    static var shouldUseMock: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-UseMockScreenTime")
        #endif
    }

    var enforcement: Enforcement {
        if isMocked { return .simulated }
        return authorization == .approved ? .shielded : .interrupted
    }

    var primaryAction: PrimaryActionKind {
        if authorization != .approved && !isMocked { return .fixAccess }
        if activeFocus != nil { return .endFocus }
        if let today, today.hasSignal, let ratio = today.budgetRatio, ratio > 1 {
            return .blockEverything
        }
        return .startFocus
    }

    // MARK: Lifecycle

    func bootstrap() async {
        if isMocked {
            try? MockScreenTimeProvider.seed(.realisticFortnight, into: ledgerStore)
            seedExampleRules()
        }
        await refresh()
    }

    func refresh() async {
        authorization = await provider.authorizationStatus
        do {
            try ledger.rollover()
            let state = try ledgerStore.load()
            health = state.health
            stage = state.stage
            streak = state.streak
            lastEntry = state.entries.last
            history = state.days
            activeFocus = state.focusSessions.first { $0.outcome == .running }
            rules = state.rules

            let provisional = try ledger.provisionalToday()
            today = provisional.record
            provisionalDelta = provisional.delta
            improvement = try ledger.improvement()
            totals = Self.totals(from: state)
            digest = WeeklyDigestBuilder.build(days: state.days, entries: state.entries)
            try awardAndNotify(from: state, today: provisional.record)
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Evaluate gems and milestone crossings, persist whatever changed, and refresh the
    /// widget.
    ///
    /// One pass, one save. Gems and milestones both live in `LedgerState`, so evaluating
    /// them separately would mean two read-modify-write cycles racing each other across
    /// the app and the intents process.
    private func awardAndNotify(from state: LedgerState, today: DayRecord) throws {
        var updated = state

        let context = GemContext(
            days: state.days,
            entries: state.entries,
            streak: state.streak,
            health: state.health,
            stage: state.stage
        )
        newlyUnlocked = GemEvaluator.evaluate(context, state: &updated.gems)
        gems = updated.gems

        // Seed once, so a fresh install at 70 does not fire every milestone under it the
        // first time the number moves.
        if !updated.milestones.hasSeeded {
            updated.milestones = milestoneWatcher.seed(at: state.health)
        }
        let crossings = milestoneWatcher.evaluate(health: state.health, state: &updated.milestones)
        milestone = milestoneWatcher.headline(from: crossings)

        if updated != state {
            try ledgerStore.save(updated)
        }

        let focusEndsAt = activeFocus.map {
            $0.startedAt.addingTimeInterval(Double($0.plannedMinutes) * 60)
        }
        snapshots.write(WidgetSnapshot(state: state, today: today, focusEndsAt: focusEndsAt))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func totals(from state: LedgerState) -> Totals {
        var t = Totals()
        for day in state.days {
            t.shields += day.shieldsShown
            t.overrides += day.overridesTaken
            t.focusSessions += day.focusSessionsCompleted
            t.focusMinutes += day.focusMinutes
            if day.hasSignal { t.measuredDays += 1 } else { t.blindDays += 1 }
        }
        return t
    }

    /// What is in force right now, and what an active allowlist has suspended.
    var ruleResolution: RuleResolution { rules.resolve(at: Date()) }

    func toggleRule(_ group: RuleGroup) {
        mutateRules { set in
            guard let index = set.groups.firstIndex(where: { $0.id == group.id }) else { return }
            set.groups[index].isEnabled.toggle()
        }
    }

    func setRuleMode(_ group: RuleGroup, to mode: BlockMode) {
        mutateRules { set in
            guard let index = set.groups.firstIndex(where: { $0.id == group.id }) else { return }
            set.groups[index].mode = mode
        }
    }

    private func mutateRules(_ body: (inout RuleSet) -> Void) {
        do {
            var state = try ledgerStore.load()
            body(&state.rules)
            try ledgerStore.save(state)
            rules = state.rules
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Two example rules, so the Blocks screen opens showing what a rule *is* rather than
    /// an empty list. Only on the mock provider, where the whole screen already says it is
    /// simulated — never on a real build, where an invented rule would be a lie about
    /// what is blocked.
    private func seedExampleRules() {
        guard isMocked else { return }
        do {
            var state = try ledgerStore.load()
            guard state.rules.groups.isEmpty else { return }
            state.rules = RuleSet(groups: [
                RuleGroup(
                    name: "The feeds",
                    selectionKey: "example.feeds",
                    budgetMinutes: 60,
                    frequencyLimit: FrequencyLimit(maxTouchedQuarterHours: 12)
                ),
                RuleGroup(
                    name: "Deep work",
                    mode: .allowlist,
                    selectionKey: "example.work",
                    budgetMinutes: 0,
                    windows: [
                        ScheduleWindow(
                            name: "Weekday mornings",
                            startMinute: 9 * 60,
                            endMinute: 12 * 60,
                            weekdays: [2, 3, 4, 5, 6]
                        )
                    ],
                    strictness: .strict,
                    isEnabled: false
                )
            ])
            try ledgerStore.save(state)
        } catch {
            loadError = String(describing: error)
        }
    }

    // MARK: Actions

    func performPrimaryAction() async {
        switch primaryAction {
        case .fixAccess:
            await requestAuthorization()
        case .startFocus:
            let session = FocusSession(startedAt: Date(), plannedMinutes: 25)
            try? ledger.recordFocus(session: session)
            try? await provider.applyShield(.all, store: StoreName.focus.rawValue)
            await refresh()
        case .endFocus:
            if var session = activeFocus {
                session.endedAt = Date()
                // Anything past 80% of the plan counts. Rounding a near-miss down to
                // nothing punishes the wrong behaviour.
                let ratio = Double(session.elapsedMinutes(now: Date())) / Double(session.plannedMinutes)
                session.outcome = ratio >= 0.8 ? .completed : .abandoned
                try? ledger.recordFocus(session: session)
            }
            try? await provider.clearShield(store: StoreName.focus.rawValue)
            await refresh()
        case .blockEverything:
            try? await provider.applyShield(.all, store: StoreName.manual.rawValue)
            await refresh()
        }
    }

    func requestAuthorization() async {
        do {
            try await provider.requestAuthorization()
        } catch {
            loadError = String(describing: error)
        }
        await refresh()
    }

    func setStrictness(_ level: Strictness) { strictness = level }

    func setBudget(_ minutes: Int) {
        budgetMinutes = minutes
        Task { await refresh() }
    }
}
