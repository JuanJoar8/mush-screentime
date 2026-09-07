import ActivityKit
import Foundation
import MushKit

/// The Lock Screen focus session.
///
/// **Why this carries an end date instead of a remaining time.** `Activity.request` only
/// works with the app in the foreground, and an app extension cannot reliably reach the
/// activity list — so the monitor extension cannot tick this down. A Live Activity that
/// needed updating would freeze the moment the phone went in a pocket, which is exactly
/// when a focus session is running.
///
/// So it never needs an update: the view renders `Text(timerInterval:)` from `endsAt`,
/// which counts down on its own, and `staleDate` retires it if the app never gets a
/// chance to end it cleanly. The only updates we send are the ones a foreground app can
/// actually make — the user ending the session early.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the session is due to end. The countdown is derived from this, not pushed.
        var endsAt: Date
        /// Stage at the moment the session started, so the Lock Screen shows the creature
        /// the user is working for. It does not change mid-session; a stage change is a
        /// daily rollover event, not a minute-by-minute one.
        var stage: BrainStage
        /// Set when the user ends early, so the final render can say so rather than
        /// showing a countdown that stopped for no visible reason.
        var endedEarly: Bool = false
    }

    /// Fixed for the life of the activity.
    var sessionKind: String
    var plannedMinutes: Int

    var title: String {
        sessionKind == FocusSession.Kind.pomodoro.rawValue ? "Pomodoro" : "Focus"
    }
}
