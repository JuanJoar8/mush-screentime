import SwiftUI
import MushKit

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

/// Composition root.
///
/// The provider is chosen at launch, never by a user-facing setting. On the Simulator —
/// and on any build without the Family Controls entitlement — the live provider cannot
/// work at all, so the mock is used and the UI says so plainly rather than showing
/// invented numbers as if they were real.
@Observable
@MainActor
final class AppModel {
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
    private(set) var loadError: String?

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

    func bootstrap() async {
        if isMocked {
            try? MockScreenTimeProvider.seed(.realisticFortnight, into: ledgerStore)
        }
        await refresh()
    }

    func refresh() async {
        authorization = await provider.authorizationStatus
        do {
            let state = try ledgerStore.load()
            health = state.health
            stage = state.stage
            streak = state.streak
            lastEntry = state.entries.last
            history = state.days
            let provisional = try ledger.provisionalToday()
            today = provisional.record
            provisionalDelta = provisional.delta
            improvement = try ledger.improvement()
            loadError = nil
        } catch {
            loadError = String(describing: error)
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
}
