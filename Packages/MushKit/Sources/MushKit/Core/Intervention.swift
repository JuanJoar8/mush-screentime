import Foundation

// MARK: - Intervention

/// The thing `Strictness.standard` makes you do before it issues a grant.
///
/// Opal puts a mini-game in the waiting room. We deliberately do not: a game is a reward,
/// and rewarding the interruption teaches the exact loop the app exists to break. The
/// waiting room should be boring, and it should cost the one thing a compulsive open has
/// none of — patience.
///
/// So the intervention is a hold. Finger down, a countdown, nothing to look at. Lift
/// early and it resets. It is not a puzzle to solve; it is time you have to spend.
public struct Intervention: Codable, Sendable, Equatable {
    /// Seconds of unbroken hold.
    public var seconds: Int
    /// Shown while holding. Present tense, no encouragement.
    public var prompt: String

    public init(seconds: Int, prompt: String) {
        self.seconds = seconds
        self.prompt = prompt
    }

    /// Nil when the level does not gate the grant behind anything.
    ///
    /// `gentle` deliberately has none — its whole definition is one tap. `strict` and
    /// `sealed` have none either, for the opposite reason: there is no grant to gate.
    public static func forStrictness(_ strictness: Strictness) -> Intervention? {
        guard strictness.requiresInterventionBeforeGrant else { return nil }
        return Intervention(seconds: 20, prompt: "Hold. Five minutes costs you two points.")
    }

    public func isSatisfied(heldFor duration: TimeInterval) -> Bool {
        duration >= Double(seconds)
    }

    /// Progress 0...1, for the ring. Clamped, so a long hold does not overflow the arc.
    public func progress(heldFor duration: TimeInterval) -> Double {
        guard seconds > 0 else { return 1 }
        return min(1, max(0, duration / Double(seconds)))
    }
}

// MARK: - Maintenance

/// Repairs the user can run when iOS leaves our shields in a state we cannot fix
/// automatically.
///
/// Brainrot ships a "Refresh" button and it is not a gimmick — FB14237883 leaves a stale
/// shield onscreen after tokens migrate between stores, and there is no callback that
/// tells us it happened. Something has to be able to tear it all down and rebuild.
///
/// Each case names what it destroys, because every one of them is destructive and the
/// confirmation sheet quotes these strings.
public enum MaintenanceAction: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Clear every named store and re-apply the shields the current rules imply.
    case reapplyShields
    /// Drop grants that outlived their usage minutes but were never revoked.
    case clearStaleGrants
    /// Stop every `DeviceActivityCenter` activity and re-register from the rule set.
    case rebuildSchedules

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .reapplyShields: "Re-apply blocks"
        case .clearStaleGrants: "Clear expired passes"
        case .rebuildSchedules: "Rebuild schedules"
        }
    }

    public var explanation: String {
        switch self {
        case .reapplyShields:
            "Removes every block, then puts back the ones your rules ask for. "
            + "Use it when a block screen appears for something you did not block, "
            + "or refuses to go away."
        case .clearStaleGrants:
            "Cancels temporary passes that should already have run out."
        case .rebuildSchedules:
            "Unregisters every window with iOS and registers them again. "
            + "Use it when a scheduled window stopped firing."
        }
    }

    /// True when running it can briefly leave apps unblocked.
    ///
    /// Surfaced in the UI. A repair that silently opens a hole in the middle of a bedtime
    /// window is worse than the bug it fixes.
    public var opensAGapWhileRunning: Bool {
        switch self {
        case .reapplyShields, .rebuildSchedules: true
        case .clearStaleGrants: false
        }
    }
}

/// What a maintenance run actually did. Shown afterwards, not just a spinner.
public struct MaintenanceReport: Sendable, Equatable, Codable {
    public var action: MaintenanceAction
    public var storesCleared: Int
    public var shieldsReapplied: Int
    public var grantsDropped: Int
    public var activitiesRebuilt: Int
    public var ranAt: Date

    public init(
        action: MaintenanceAction,
        storesCleared: Int = 0,
        shieldsReapplied: Int = 0,
        grantsDropped: Int = 0,
        activitiesRebuilt: Int = 0,
        ranAt: Date = Date()
    ) {
        self.action = action
        self.storesCleared = storesCleared
        self.shieldsReapplied = shieldsReapplied
        self.grantsDropped = grantsDropped
        self.activitiesRebuilt = activitiesRebuilt
        self.ranAt = ranAt
    }

    public var summary: String {
        switch action {
        case .reapplyShields:
            "Cleared \(storesCleared), re-applied \(shieldsReapplied)."
        case .clearStaleGrants:
            grantsDropped == 0 ? "Nothing to clear." : "Dropped \(grantsDropped)."
        case .rebuildSchedules:
            "Rebuilt \(activitiesRebuilt)."
        }
    }
}

/// Grants that have outlived their usage allowance.
public enum GrantMaintenance {
    /// A grant is stale when more wall-clock time has passed than its usage minutes could
    /// possibly have consumed — you cannot spend 5 usage-minutes in under 5 real minutes.
    ///
    /// Same physical invariant the ladder validator uses: usage time cannot outrun
    /// wall-clock time. It is a floor, so this only ever drops grants that are certainly
    /// dead, never ones that might still be live.
    public static func stale(_ grants: [Grant], now: Date) -> [Grant] {
        grants.filter { now.timeIntervalSince($0.issuedAt) > Double($0.usageMinutes) * 60 }
    }
}
