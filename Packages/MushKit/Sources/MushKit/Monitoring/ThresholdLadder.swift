import Foundation

/// The usage sensor.
///
/// `eventDidReachThreshold` in the monitor extension is the **only** usage signal we are
/// allowed to persist (docs/01-FEASIBILITY.md section 3). So we register a ladder of
/// `DeviceActivityEvent`s at increasing usage thresholds and read each firing as
/// "the user has now crossed rung k".
///
/// Resolution equals the step. Finer steps mean more events, more battery, and more
/// exposure to the iOS 26.x threshold bugs — 5 minutes is a deliberate compromise, to be
/// re-tuned on real hardware in Phase 10.
public struct ThresholdLadder: Sendable, Equatable {
    public let stepMinutes: Int
    public let maxRungs: Int

    /// `maxRungs` default is a guess with a safety margin: Apple documents no ceiling on
    /// events per activity (open question Q2). Treat it as a guardrail, not a known limit.
    public init(stepMinutes: Int = 5, maxRungs: Int = 48) {
        precondition(stepMinutes > 0, "step must be positive")
        self.stepMinutes = stepMinutes
        self.maxRungs = maxRungs
    }

    /// Usage-minute thresholds to register for a given daily budget.
    ///
    /// The ladder climbs to twice the budget so overshoot stays measurable — a user at
    /// 3x budget and one at 1.1x must not look identical to the scoring model.
    public func thresholds(budgetMinutes: Int) -> [Int] {
        guard budgetMinutes > 0 else { return [] }
        let ceiling = budgetMinutes * 2
        let count = min(max(ceiling / stepMinutes, 1), maxRungs)
        return (1...count).map { $0 * stepMinutes }
    }

    /// Rung index for a threshold value, 1-based.
    public func rung(forThreshold minutes: Int) -> Int { minutes / stepMinutes }

    /// Minutes represented by having reached rung `k`.
    public func minutes(atRung k: Int) -> Int { k * stepMinutes }

    /// The rung at which the daily budget is exhausted and the limit shield applies.
    public func budgetRung(budgetMinutes: Int) -> Int {
        max(1, Int((Double(budgetMinutes) / Double(stepMinutes)).rounded(.up)))
    }
}

// MARK: - Firings

/// One raw `eventDidReachThreshold` callback, as it arrived.
public struct LadderFiring: Codable, Sendable, Equatable {
    public var rung: Int
    public var at: Date
    public init(rung: Int, at: Date) {
        self.rung = rung
        self.at = at
    }
}

/// Why a firing was rejected.
public enum FiringRejection: String, Codable, Sendable, Equatable {
    /// Arrived faster than the wall clock physically allows.
    case impossiblySoon
    /// A rung we have already accepted.
    case duplicate
    /// A rung below one we have already accepted.
    case regression
}

public enum FiringDecision: Sendable, Equatable {
    case accepted
    case rejected(FiringRejection)
}

/// Defence against the iOS 26.x threshold regressions (docs/01-FEASIBILITY.md L10):
/// thresholds have been reported firing early, firing with zero recorded minutes, and
/// firing repeatedly within seconds.
///
/// The invariant we lean on is physical and cannot be argued with: **app usage time can
/// never exceed elapsed wall-clock time.** If two rungs five usage-minutes apart arrive
/// forty seconds apart, at least one of them is wrong.
public struct ThresholdValidator: Sendable {
    public let stepMinutes: Int
    /// Slack for clock skew and callback latency. 0.8 means we accept a firing that
    /// claims 5 usage-minutes after 4 wall-clock minutes.
    public let tolerance: Double

    public init(stepMinutes: Int, tolerance: Double = 0.8) {
        self.stepMinutes = stepMinutes
        self.tolerance = tolerance
    }

    public func decide(_ firing: LadderFiring, lastAccepted: LadderFiring?) -> FiringDecision {
        guard let last = lastAccepted else { return .accepted }
        if firing.rung == last.rung { return .rejected(.duplicate) }
        if firing.rung < last.rung { return .rejected(.regression) }

        let claimedUsageSeconds = Double(firing.rung - last.rung) * Double(stepMinutes) * 60
        let elapsedSeconds = firing.at.timeIntervalSince(last.at)
        if elapsedSeconds < claimedUsageSeconds * tolerance {
            return .rejected(.impossiblySoon)
        }
        return .accepted
    }
}

/// Accepted and rejected firings for one day, kept together so the discrepancy stays
/// auditable rather than silently discarded.
public struct LadderLog: Codable, Sendable, Equatable {
    public var accepted: [LadderFiring] = []
    public var rejected: [LadderFiring] = []

    public init(accepted: [LadderFiring] = [], rejected: [LadderFiring] = []) {
        self.accepted = accepted
        self.rejected = rejected
    }

    public var highestAcceptedRung: Int { accepted.map(\.rung).max() ?? 0 }
    public var lastAccepted: LadderFiring? { accepted.max(by: { $0.at < $1.at }) }

    /// Any firing at all — accepted or not — means the extension woke and the pipeline
    /// is alive. That is what distinguishes a genuine zero-usage day from a blind day.
    public var hasSignal: Bool { !accepted.isEmpty || !rejected.isEmpty }

    public mutating func record(
        _ firing: LadderFiring,
        validator: ThresholdValidator
    ) -> FiringDecision {
        let decision = validator.decide(firing, lastAccepted: lastAccepted)
        switch decision {
        case .accepted: accepted.append(firing)
        case .rejected: rejected.append(firing)
        }
        return decision
    }
}
