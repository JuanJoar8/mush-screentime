import Foundation

/// Identifiers shared by the app and every extension.
///
/// The App Group is the *only* channel between them. The report extension is the one
/// exception: it is sandboxed and can neither read nor write here
/// (docs/01-FEASIBILITY.md section 3).
public enum MushIdentifiers {
    /// Keep in sync with `Config/Shared.xcconfig` -> `APP_GROUP_ID`.
    public static let appGroup = "group.com.mush.app"
}

/// One `ManagedSettingsStore` per concern, never a single shared store.
///
/// Mitigation for FB14237883: tokens migrating between stores can leave a stale shield
/// UI onscreen. Keeping concerns in separate named stores means we can tear one down
/// cleanly without disturbing the others.
public enum StoreName: String, Codable, Sendable, CaseIterable {
    /// User pressed "block now".
    case manual
    /// A daily budget was exhausted.
    case limit
    /// An active focus or Pomodoro session.
    case focus
    /// Feed Quarantine layer 1 (docs/05-SHORTS-REELS.md).
    case quarantine

    /// Recurring windows get one store each, keyed by the window's stable UUID.
    public static func schedule(_ id: UUID) -> String { "schedule.\(id.uuidString)" }
}

/// Names for `DeviceActivityCenter` activities. Kept short: they end up in system logs.
public enum ActivityName {
    public static let dailyLadder = "mush.ladder.daily"
    public static func window(_ id: UUID) -> String { "mush.window.\(id.uuidString)" }
    public static func grant(_ id: UUID) -> String { "mush.grant.\(id.uuidString)" }
}
