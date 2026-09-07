import Foundation

/// The four health levels worth telling someone about.
///
/// Brainrot notifies at 75 / 50 / 25 / 10 %. Same four numbers here, because they are the
/// right ones: they sit near the stage boundaries in `04-BRAIN-HEALTH.md`, so a crossing
/// is also the moment the creature visibly changes.
public enum HealthMilestone: Int, Codable, Sendable, CaseIterable, Comparable {
    case ten = 10
    case twentyFive = 25
    case fifty = 50
    case seventyFive = 75

    public static func < (a: HealthMilestone, b: HealthMilestone) -> Bool {
        a.rawValue < b.rawValue
    }

    public var level: Double { Double(rawValue) }
}

public enum CrossingDirection: String, Codable, Sendable {
    case falling, rising
}

/// One notification's worth of event.
public struct MilestoneCrossing: Sendable, Equatable, Identifiable {
    public var milestone: HealthMilestone
    public var direction: CrossingDirection
    public var health: Double

    public var id: String { "\(milestone.rawValue).\(direction.rawValue)" }

    /// Dry, specific, no coaching. The number is the message.
    public var message: String {
        switch (direction, milestone) {
        case (.falling, .seventyFive): "Down through 75. It's starting to look tired."
        case (.falling, .fifty): "Down through 50. Half gone."
        case (.falling, .twentyFive): "Down through 25. It is not holding shape."
        case (.falling, .ten): "Down through 10. There is not much left of it."
        case (.rising, .seventyFive): "Back over 75. It's holding shape again."
        case (.rising, .fifty): "Back over 50."
        case (.rising, .twentyFive): "Back over 25."
        case (.rising, .ten): "Back over 10."
        }
    }
}

/// Which milestones have already been announced on the way down.
public struct MilestoneState: Codable, Sendable, Equatable {
    public var announcedFalling: Set<Int>
    /// Whether `seed(at:)` has run. Without this flag the caller has to infer "is this a
    /// fresh install?" from an empty set — which is also what a healthy user at 90 looks
    /// like, and they would get every milestone fired at them the first time they dipped.
    public var hasSeeded: Bool

    public init(announcedFalling: Set<Int> = [], hasSeeded: Bool = false) {
        self.announcedFalling = announcedFalling
        self.hasSeeded = hasSeeded
    }

    // Lenient, for the same reason `LedgerState` is: a field added later must not make an
    // existing ledger undecodable.
    private enum CodingKeys: String, CodingKey { case announcedFalling, hasSeeded }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        announcedFalling = try container.decodeIfPresent(Set<Int>.self, forKey: .announcedFalling) ?? []
        hasSeeded = try container.decodeIfPresent(Bool.self, forKey: .hasSeeded) ?? false
    }
}

/// Turns a moving health number into at most a few notifications.
///
/// The whole job here is **not sending four notifications when a number hovers on 50**.
/// The rule:
///
/// - A falling crossing fires when health reaches or drops below the level, and only if
///   that level is not already announced.
/// - The level re-arms only once health climbs back to `level + hysteresis`. Sitting at
///   49.9 all week fires once.
/// - A rising crossing fires at that same re-arm point, and only for a level that was
///   actually announced on the way down — so a fresh install at 70 climbing to 80 does
///   not congratulate you for passing 75, 50, 25 and 10.
///
/// The default hysteresis matches `BrainHealthConfig.stageHysteresis`, so a milestone
/// notification and a visible stage change happen together rather than a day apart.
public struct MilestoneWatcher: Sendable {
    public var hysteresis: Double

    public init(hysteresis: Double = 3) {
        self.hysteresis = hysteresis
    }

    /// Seed state for a health value we have never observed before.
    ///
    /// Call this once, at install or after a reset. Without it the first evaluation of a
    /// low health value would fire every milestone beneath it at once.
    public func seed(at health: Double) -> MilestoneState {
        MilestoneState(
            announcedFalling: Set(
                HealthMilestone.allCases.filter { health <= $0.level }.map(\.rawValue)
            ),
            hasSeeded: true
        )
    }

    public func evaluate(health: Double, state: inout MilestoneState) -> [MilestoneCrossing] {
        var crossings: [MilestoneCrossing] = []

        // Falling, highest first: a plunge from 80 to 5 reports the deepest levels last,
        // and the caller can choose to notify only about the last one.
        for milestone in HealthMilestone.allCases.sorted(by: >) {
            let isAnnounced = state.announcedFalling.contains(milestone.rawValue)
            if health <= milestone.level, !isAnnounced {
                state.announcedFalling.insert(milestone.rawValue)
                crossings.append(
                    MilestoneCrossing(milestone: milestone, direction: .falling, health: health)
                )
            }
        }

        // Rising, lowest first, and only for levels we announced on the way down.
        for milestone in HealthMilestone.allCases {
            let isAnnounced = state.announcedFalling.contains(milestone.rawValue)
            if health >= milestone.level + hysteresis, isAnnounced {
                state.announcedFalling.remove(milestone.rawValue)
                crossings.append(
                    MilestoneCrossing(milestone: milestone, direction: .rising, health: health)
                )
            }
        }

        return crossings
    }

    /// The one crossing worth a notification, when several fired at once.
    ///
    /// A single drop can cross three levels. Sending three notifications for one event is
    /// how an app gets its notifications switched off, so we send the deepest fall or the
    /// highest recovery and drop the rest.
    public func headline(from crossings: [MilestoneCrossing]) -> MilestoneCrossing? {
        if let deepest = crossings.filter({ $0.direction == .falling }).min(by: {
            $0.milestone < $1.milestone
        }) {
            return deepest
        }
        return crossings.filter { $0.direction == .rising }.max(by: {
            $0.milestone < $1.milestone
        })
    }
}
