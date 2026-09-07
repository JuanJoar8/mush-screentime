import Foundation

/// Mirrors `FamilyControls.AuthorizationStatus` without importing it, so this module
/// stays pure and testable off-device.
public enum MushAuthorizationStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined
    case denied
    case approved
    /// The app is running somewhere Family Controls cannot work at all: the Simulator,
    /// or a device provisioned by a free Personal Team. Distinct from `denied` because
    /// the user did nothing wrong and there is no prompt to re-show.
    case unavailable
}

public enum ShieldTarget: Sendable, Equatable {
    case applications
    case categories
    case webDomains
    case all
}

/// A request to start monitoring. Deliberately expressed in our own vocabulary; the live
/// provider translates it into `DeviceActivitySchedule` and `DeviceActivityEvent`.
public struct MonitoringPlan: Sendable, Equatable {
    public var activityName: String
    public var startMinute: Int
    public var endMinute: Int
    public var repeats: Bool
    /// Usage-minute thresholds from `ThresholdLadder.thresholds(budgetMinutes:)`.
    public var thresholds: [Int]

    public init(
        activityName: String,
        startMinute: Int,
        endMinute: Int,
        repeats: Bool = true,
        thresholds: [Int] = []
    ) {
        self.activityName = activityName
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.repeats = repeats
        self.thresholds = thresholds
    }

    /// `DeviceActivitySchedule` rejects intervals under 15 minutes
    /// (docs/01-FEASIBILITY.md L3). Validate before calling, not after failing.
    public var isValid: Bool {
        let span = endMinute <= startMinute
            ? (1440 - startMinute) + endMinute
            : endMinute - startMinute
        return span >= 15
    }
}

public enum ScreenTimeError: Error, Sendable, Equatable {
    case notAuthorized
    /// Raised when Family Controls cannot work here at all. Carries the reason so the UI
    /// can say something true instead of "something went wrong".
    case unavailable(String)
    case scheduleTooShort
    case tokenSelectionEmpty
}

/// The seam between the product and Apple's frameworks.
///
/// Everything above this line is testable from Windows. Everything below it needs a
/// paid Apple Developer membership and a physical device (docs/08-DECISIONS.md D7).
public protocol ScreenTimeProviding: Sendable {
    var authorizationStatus: MushAuthorizationStatus { get async }

    func requestAuthorization() async throws

    /// Number of items the user has picked. The tokens themselves are opaque and never
    /// leave the provider.
    var selectionCount: Int { get async }

    func applyShield(_ target: ShieldTarget, store: String) async throws
    func clearShield(store: String) async throws
    func activeShieldStores() async -> [String]

    func startMonitoring(_ plan: MonitoringPlan) async throws
    func stopMonitoring(activityName: String) async throws
    func activeActivities() async -> [String]
}
