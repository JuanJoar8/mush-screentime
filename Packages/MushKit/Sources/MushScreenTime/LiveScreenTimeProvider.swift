#if os(iOS)
import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import MushKit

/// The real Screen Time implementation.
///
/// Everything in this file requires a paid Apple Developer membership and a physical
/// device. It does nothing useful in the Simulator — Family Controls authorization
/// fails there unconditionally — which is why `MockScreenTimeProvider` exists.
public actor LiveScreenTimeProvider: ScreenTimeProviding {

    private let center = DeviceActivityCenter()
    private let selectionStore: SelectionStore

    public init(selectionStore: SelectionStore = SelectionStore()) {
        self.selectionStore = selectionStore
    }

    // MARK: Authorization

    public var authorizationStatus: MushAuthorizationStatus {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .approved: .approved
        @unknown default: .notDetermined
        }
    }

    public func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The most common cause by far is a provisioning problem rather than a user
            // refusal: a free Personal Team cannot carry the family-controls entitlement,
            // so the request fails before any prompt is shown. Say that, instead of
            // reporting a generic failure the user cannot act on.
            throw ScreenTimeError.unavailable(
                "Screen Time access could not be requested. On a development build this "
                + "usually means the Family Controls entitlement is missing, which "
                + "requires a paid Apple Developer membership."
            )
        }
    }

    public var selectionCount: Int {
        let selection = selectionStore.load()
        return selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    // MARK: Shields

    public func applyShield(_ target: ShieldTarget, store name: String) async throws {
        guard authorizationStatus == .approved else { throw ScreenTimeError.notAuthorized }
        let selection = selectionStore.load()
        guard selectionCount > 0 else { throw ScreenTimeError.tokenSelectionEmpty }

        let store = ManagedSettingsStore(named: .init(name))

        if target == .applications || target == .all {
            store.shield.applications = selection.applicationTokens.isEmpty
                ? nil : selection.applicationTokens
        }
        if target == .categories || target == .all {
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil : .specific(selection.categoryTokens)
        }
        if target == .webDomains || target == .all {
            // Deliberately host-level only: `WebDomain` has no path granularity
            // (docs/01-FEASIBILITY.md L4). Never shield a domain that Clean Feed serves
            // until open question Q1 is answered on device.
            store.shield.webDomains = selection.webDomainTokens.isEmpty
                ? nil : selection.webDomainTokens
        }
    }

    public func clearShield(store name: String) async throws {
        // Clear the whole named store rather than nilling individual properties: tokens
        // left behind in a store are the reported cause of stale shield UI (FB14237883).
        ManagedSettingsStore(named: .init(name)).clearAllSettings()
    }

    public func activeShieldStores() async -> [String] {
        StoreName.allCases
            .map(\.rawValue)
            .filter { ManagedSettingsStore(named: .init($0)).shield.applications?.isEmpty == false }
    }

    // MARK: Monitoring

    public func startMonitoring(_ plan: MonitoringPlan) async throws {
        guard authorizationStatus == .approved else { throw ScreenTimeError.notAuthorized }
        guard plan.isValid else { throw ScreenTimeError.scheduleTooShort }

        let selection = selectionStore.load()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: plan.startMinute / 60, minute: plan.startMinute % 60),
            intervalEnd: DateComponents(hour: plan.endMinute / 60, minute: plan.endMinute % 60),
            repeats: plan.repeats
        )

        // The threshold ladder. Each event name encodes its rung so the monitor
        // extension can decode it without shared mutable state.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for threshold in plan.thresholds {
            let rung = threshold / ThresholdLadder().stepMinutes
            events[DeviceActivityEvent.Name(LadderEventName.encode(rung: rung))] =
                DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    webDomains: selection.webDomainTokens,
                    threshold: DateComponents(minute: threshold)
                )
        }

        center.stopMonitoring([DeviceActivityName(plan.activityName)])
        try center.startMonitoring(
            DeviceActivityName(plan.activityName),
            during: schedule,
            events: events
        )
    }

    public func stopMonitoring(activityName: String) async throws {
        center.stopMonitoring([DeviceActivityName(activityName)])
    }

    public func activeActivities() async -> [String] {
        center.activities.map(\.rawValue)
    }
}

/// Event names carry their rung, because the monitor extension is woken cold and has no
/// other way to know which threshold fired.
public enum LadderEventName {
    private static let prefix = "mush.rung."

    public static func encode(rung: Int) -> String { "\(prefix)\(rung)" }

    public static func decode(_ name: String) -> Int? {
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }
}

/// Persists the user's `FamilyActivitySelection` in the App Group.
///
/// The tokens inside are opaque and can silently rotate at runtime (FB14082790), so this
/// is treated as a cache of the *current* tokens, never as a stable identity.
public struct SelectionStore: Sendable {
    private let key = "mush.selection"
    private let appGroup: String

    public init(appGroup: String = MushIdentifiers.appGroup) {
        self.appGroup = appGroup
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    public func load() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    public func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: key)
    }
}
#endif
