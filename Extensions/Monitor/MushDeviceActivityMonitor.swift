import DeviceActivity
import Foundation
import MushKit
import MushScreenTime

/// The only place in the system where usage can be observed and persisted.
///
/// Woken cold by the system, given a few hundred milliseconds, and running under a tight
/// memory budget. Keep the work here small, synchronous and allocation-light.
class MushDeviceActivityMonitor: DeviceActivityMonitor {

    private var ledger: UsageLedger? {
        guard let store = try? FileLedgerStore() else { return nil }
        return UsageLedger(store: store)
    }

    // MARK: Scheduled windows

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let plan = WindowPlanStore().plan(forActivity: activity.rawValue) else { return }
        BlockApplier.apply(storeName: plan.storeName)
        try? ledger?.recordWindowStarted()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let plan = WindowPlanStore().plan(forActivity: activity.rawValue) else { return }
        BlockApplier.clear(storeName: plan.storeName)
        try? ledger?.recordWindowEnded()
    }

    // MARK: Thresholds

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // A grant expiring is a different kind of event: re-apply the shield the user
        // bought their way past. Grants are measured in usage time, not wall clock,
        // because DeviceActivitySchedule cannot express an interval under 15 minutes
        // (docs/08-DECISIONS.md D5).
        if let grantStore = GrantEventName.decode(event.rawValue) {
            BlockApplier.apply(storeName: grantStore)
            GrantStore().clear(storeName: grantStore)
            return
        }

        guard let rung = LadderEventName.decode(event.rawValue), let ledger else { return }

        // Treat the firing as a hint, never as proof. iOS 26.2 and 26.3 have been
        // reported firing thresholds early, at zero recorded minutes, and in bursts
        // (docs/01-FEASIBILITY.md L10). recordFiring applies the wall-clock sanity check
        // and tells us whether this one survived it.
        guard let decision = try? ledger.recordFiring(rung: rung, at: Date()),
              decision == .accepted else { return }

        // Only an accepted rung may trip the daily limit. Shielding on an unvalidated
        // firing is exactly how the iOS 26.2 regression locked people out of their apps.
        let ladder = ThresholdLadder()
        if rung >= ladder.budgetRung(budgetMinutes: BudgetStore().budgetMinutes) {
            BlockApplier.apply(storeName: StoreName.limit.rawValue)
        }
    }
}
