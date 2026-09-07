import Foundation

/// A watched app was just opened, and the app has been foregrounded to interrupt it.
///
/// Ephemeral by design: this lives in the App Group's `UserDefaults`, not the ledger. It
/// describes one moment, it is consumed on the next launch, and a stale one is worse than
/// none — a pause screen for something you opened an hour ago is nonsense.
///
/// **Why this exists.** Without the Family Controls entitlement nothing can stop an app
/// from opening. What a Shortcuts personal automation *can* do is fire the instant a
/// watched app launches and run an App Intent that foregrounds us — the mechanism `one
/// sec` has shipped on for years (`docs/09-PATH-B-NO-ENTITLEMENT.md`). The user ends up
/// looking at this app instead of the feed. That is friction, not a block, and the copy
/// never claims otherwise.
public struct PendingInterruption: Codable, Sendable, Equatable {
    /// Our own stable key for the app, e.g. "instagram". Path B never sees a token.
    public var appKey: String
    /// Display name, as the user typed it when they set the automation up.
    public var appName: String
    public var firedAt: Date

    public init(appKey: String, appName: String, firedAt: Date = Date()) {
        self.appKey = appKey
        self.appName = appName
        self.firedAt = firedAt
    }

    /// Interruptions go stale fast. Beyond this, showing the pause would be confusing
    /// rather than useful — the user has long since moved on.
    public static let freshness: TimeInterval = 45

    public func isFresh(at date: Date = Date()) -> Bool {
        let age = date.timeIntervalSince(firedAt)
        return age >= 0 && age <= Self.freshness
    }
}

/// Hands the interruption from the App Intent process to the app process.
public struct InterruptionInbox: Sendable {
    public static let key = "mush.interruption.pending"

    private let suiteName: String

    public init(appGroup: String = MushIdentifiers.appGroup) {
        self.suiteName = appGroup
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    public func post(_ interruption: PendingInterruption) {
        guard let data = try? JSONEncoder().encode(interruption) else { return }
        defaults?.set(data, forKey: Self.key)
    }

    /// Read and clear. Returns nil for a stale one, and clears it either way — an
    /// interruption is consumed by being seen, or by being too late to matter.
    public func take(at date: Date = Date()) -> PendingInterruption? {
        guard let data = defaults?.data(forKey: Self.key),
              let pending = try? JSONDecoder().decode(PendingInterruption.self, from: data)
        else { return nil }
        defaults?.removeObject(forKey: Self.key)
        return pending.isFresh(at: date) ? pending : nil
    }
}

/// What the user did when the pause appeared.
///
/// Both outcomes are recorded. An app that only counted its wins would be lying to the
/// one person it exists to inform.
public enum InterruptionOutcome: String, Codable, Sendable, CaseIterable {
    /// They waited it out and went back. The intervention worked.
    case turnedBack
    /// They pushed through to the app. It still counts, and it still costs.
    case continued

    public var title: String {
        switch self {
        case .turnedBack: "Turned back"
        case .continued: "Continued"
        }
    }
}
