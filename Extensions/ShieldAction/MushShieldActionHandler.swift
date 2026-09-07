import DeviceActivity
import Foundation
import ManagedSettings
import MushKit
import MushScreenTime

/// Handles the two buttons on the block screen.
///
/// Hard constraint: this extension **cannot open our app**. Only `.none`, `.close` and
/// `.defer` exist; `UIApplication.open` and `NSExtensionContext` are both unavailable
/// here, and Apple has stated there is no supported way (FB15079668). So the grant is
/// issued right here rather than by bouncing the user into Mush.
class MushShieldActionHandler: ShieldActionDelegate {

    private var ledger: UsageLedger? {
        guard let store = try? FileLedgerStore() else { return nil }
        return UsageLedger(store: store)
    }

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // "Close". The shield did its job.
            try? ledger?.recordShieldEvent(shown: 1)
            completionHandler(.close)

        case .secondaryButtonPressed:
            let strictness = StrictnessStore().strictness
            guard strictness.allowsOverride else {
                completionHandler(.none)
                return
            }
            issueGrant(for: application, minutes: strictness.grantMinutes)
            // `.close` rather than `.none`: the app is now unshielded, and iOS gives us
            // no way to launch it for the user (FB15500695). They reopen it themselves.
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        try? ledger?.recordShieldEvent(shown: 1)
        completionHandler(action == .primaryButtonPressed ? .close : .none)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        try? ledger?.recordShieldEvent(shown: 1)
        completionHandler(action == .primaryButtonPressed ? .close : .none)
    }

    // MARK: -

    /// Grants temporary access and arms its own expiry.
    ///
    /// The expiry is a `DeviceActivityEvent` threshold, not a schedule, because
    /// `DeviceActivitySchedule` refuses any interval under 15 minutes
    /// (docs/01-FEASIBILITY.md L3). The side effect is that the grant is measured in
    /// *usage* minutes — five minutes of actually being in the app, not five minutes of
    /// the clock. That is the better behaviour anyway.
    private func issueGrant(for application: ApplicationToken, minutes: Int) {
        let storeName = StoreName.limit.rawValue

        BlockApplier.unshield(token: application, storeName: storeName)
        GrantStore().add(Grant(storeName: storeName, issuedAt: Date(), usageMinutes: minutes))
        try? ledger?.recordShieldEvent(shown: 1, overrides: 1, grants: 1)

        let center = DeviceActivityCenter()
        let activity = DeviceActivityName(ActivityName.grant(UUID()))
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let end = Calendar.current.dateComponents(
            [.hour, .minute],
            from: Date().addingTimeInterval(60 * 60)
        )

        let event = DeviceActivityEvent(
            applications: [application],
            threshold: DateComponents(minute: minutes)
        )

        try? center.startMonitoring(
            activity,
            during: DeviceActivitySchedule(
                intervalStart: now,
                intervalEnd: end,
                repeats: false
            ),
            events: [DeviceActivityEvent.Name(GrantEventName.encode(storeName: storeName)): event]
        )
    }
}
