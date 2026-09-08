import Foundation
import MushKit
import UserNotifications

/// Local notifications, and the restraint that makes them survivable.
///
/// `MilestoneWatcher` already decides *whether* a crossing is worth reporting — with
/// hysteresis, so a number hovering on 50 cannot fire twice. This type only decides
/// whether we are allowed to say it, and says it once.
///
/// **Three rules, all of them refusals:**
///
/// 1. **Never ask for permission at launch.** A prompt before the app has done anything
///    is the fastest way to a permanent no. We ask the first time there is genuinely
///    something to say.
/// 2. **One notification per crossing, never per level.** A drop from 90 to 5 crosses
///    four thresholds; the watcher hands us the deepest and the rest are dropped.
/// 3. **No streak-loss guilt, no encouragement.** The message states the number and
///    stops (`02-PRODUCT.md` §1).
@MainActor
final class MushNotifier {
    static let shared = MushNotifier()

    private let center = UNUserNotificationCenter.current()
    private var didAsk = false

    private init() {}

    /// Ask only when we have something to deliver. Returns whether we may post.
    private func ensureAuthorized() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard !didAsk else { return false }
            didAsk = true
            // Provisional: it delivers quietly to the notification centre without a
            // prompt, and the user promotes or silences it from the notification itself.
            // For something that fires a handful of times a month, asking outright buys
            // nothing and risks a permanent refusal.
            return (try? await center.requestAuthorization(options: [.alert, .provisional])) ?? false
        @unknown default:
            return false
        }
    }

    /// Post a health-milestone crossing.
    func post(_ crossing: MilestoneCrossing) async {
        guard await ensureAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = crossing.direction == .falling ? "It slipped" : "It came back"
        content.body = crossing.message
        content.interruptionLevel = crossing.direction == .falling ? .active : .passive
        content.sound = nil

        // Identifier keyed to level and direction, so a repeat of the same crossing
        // replaces the previous notification rather than stacking under it.
        let request = UNNotificationRequest(
            identifier: "mush.milestone.\(crossing.id)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// Post a gem unlock. Quiet by design — the gem itself is the reward, and a chime for
    /// a thing you earned by not looking at your phone would be a poor joke.
    func post(unlocked gem: Gem) async {
        guard await ensureAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = gem.title
        content.body = gem.requirement
        content.interruptionLevel = .passive
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "mush.gem.\(gem.id)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
