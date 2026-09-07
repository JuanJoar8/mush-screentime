import Foundation

// The model specified in docs/04-BRAIN-HEALTH.md. Keep the two in sync: if you change a
// number here, change it there, and add a golden test.

// MARK: - Stages

public enum BrainStage: Int, Codable, Sendable, CaseIterable, Comparable {
    case mush = 0, melting, buzzed, foggy, crisp

    public static func < (a: BrainStage, b: BrainStage) -> Bool { a.rawValue < b.rawValue }

    /// Inclusive lower bound of the stage's health range.
    public var lowerBound: Double {
        switch self {
        case .mush: 0
        case .melting: 25
        case .buzzed: 45
        case .foggy: 65
        case .crisp: 85
        }
    }

    public var title: String {
        switch self {
        case .crisp: "Crisp"
        case .foggy: "Foggy"
        case .buzzed: "Buzzed"
        case .melting: "Melting"
        case .mush: "Mush"
        }
    }

    /// Note that `buzzed` is the *most agitated* state, not a midpoint between alert and
    /// asleep. The character gets jittery before it starts drooping — which is what an
    /// overstimulated afternoon actually feels like.
    public var mood: String {
        switch self {
        case .crisp: "alert, holding shape"
        case .foggy: "a bit hazy, still fine"
        case .buzzed: "overstimulated, twitchy"
        case .melting: "drooping, losing shape"
        case .mush: "puddled"
        }
    }

    /// Raw stage for a health value, ignoring hysteresis.
    public static func raw(for health: Double) -> BrainStage {
        switch health {
        case 85...: .crisp
        case 65..<85: .foggy
        case 45..<65: .buzzed
        case 25..<45: .melting
        default: .mush
        }
    }

    /// Stage with hysteresis applied.
    ///
    /// A score oscillating around a boundary would otherwise flip the character daily,
    /// which reads as broken rather than responsive. Crossing costs `hysteresis` points
    /// of overshoot in whichever direction you are moving.
    public static func resolved(
        health: Double,
        previous: BrainStage?,
        hysteresis: Double
    ) -> BrainStage {
        guard let previous else { return raw(for: health) }
        var stage = previous
        // Climb while we clear the next boundary by the hysteresis margin.
        while stage != .crisp,
              let next = BrainStage(rawValue: stage.rawValue + 1),
              health >= next.lowerBound + hysteresis {
            stage = next
        }
        // Fall while we drop below our own floor by the hysteresis margin.
        while stage != .mush, health <= stage.lowerBound - hysteresis {
            stage = BrainStage(rawValue: stage.rawValue - 1) ?? .mush
        }
        return stage
    }
}

// MARK: - Configuration

public struct BrainHealthConfig: Sendable, Equatable {
    public var startingHealth: Double = 70

    public var dailyClamp: ClosedRange<Double> = -20...15

    // C1 budget anchors
    public var budgetFlatUntil: Double = 0.5
    public var budgetMaxBonus: Double = 10
    public var budgetZeroAt: Double = 1.0
    public var budgetFloorAt: Double = 2.0
    public var budgetMaxPenalty: Double = -25

    // C2 focus
    public var focusPerSession: Double = 3
    public var focusMaxSessions: Int = 3

    // C3 overrides
    public var overridePenalty: Double = -2
    public var overrideMaxCount: Int = 5

    // C4 schedules
    public var scheduleBonus: Double = 4

    // C5 streak
    public var streakDaysPerPoint: Int = 3
    public var streakMaxBonus: Double = 5

    // C6 comeback
    public var comebackThreshold: Double = 30
    public var comebackBonus: Double = 3

    public var stageHysteresis: Double = 3

    public init() {}
}

// MARK: - Contributions

/// One named, signed term of the daily delta. Rendered verbatim on the Receipt screen —
/// this is what makes the score trustworthy.
public struct Contribution: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case budget, focus, overrides, schedule, streak, comeback
    }

    public var kind: Kind
    public var value: Double
    /// Human sentence, e.g. "Over budget by 36 min".
    public var reason: String

    public var id: String { kind.rawValue }

    public init(kind: Kind, value: Double, reason: String) {
        self.kind = kind
        self.value = value
        self.reason = reason
    }
}

/// The committed result of one day's evaluation.
public struct HealthEntry: Codable, Sendable, Equatable, Identifiable {
    public var date: Date
    public var healthBefore: Double
    public var healthAfter: Double
    public var contributions: [Contribution]
    /// Sum before clamping. Differs from `delta` when the clamp bit.
    public var rawDelta: Double
    public var delta: Double
    public var wasClamped: Bool
    public var stageBefore: BrainStage
    public var stageAfter: BrainStage
    public var hadSignal: Bool
    public var streakAfter: Int

    public var id: Date { date }
}

/// Facts about history that the engine needs but cannot derive from a single day.
public struct EvaluationContext: Sendable, Equatable {
    public var currentHealth: Double
    public var currentStage: BrainStage?
    /// Consecutive green days ending yesterday.
    public var streakBefore: Int

    public init(currentHealth: Double, currentStage: BrainStage? = nil, streakBefore: Int = 0) {
        self.currentHealth = currentHealth
        self.currentStage = currentStage
        self.streakBefore = streakBefore
    }
}

// MARK: - Engine

public struct BrainHealthEngine: Sendable {
    public let config: BrainHealthConfig

    public init(config: BrainHealthConfig = BrainHealthConfig()) {
        self.config = config
    }

    // MARK: C1 — budget adherence

    /// Piecewise linear through (0.5, +10), (1.0, 0), (2.0, -25).
    public func budgetContribution(ratio r: Double) -> Double {
        let c = config
        if r <= c.budgetFlatUntil { return c.budgetMaxBonus }
        if r <= c.budgetZeroAt {
            let span = c.budgetZeroAt - c.budgetFlatUntil
            let t = (r - c.budgetFlatUntil) / span
            return c.budgetMaxBonus * (1 - t)
        }
        if r <= c.budgetFloorAt {
            let span = c.budgetFloorAt - c.budgetZeroAt
            let t = (r - c.budgetZeroAt) / span
            return c.budgetMaxPenalty * t
        }
        return c.budgetMaxPenalty
    }

    // MARK: All contributions

    public func contributions(for day: DayRecord, context: EvaluationContext) -> [Contribution] {
        // A day with no signal scores nothing at all. We never guess a number Apple did
        // not give us, and with the iOS 26.x threshold regressions, trusting a silent
        // zero would be actively wrong (docs/08-DECISIONS.md D8).
        guard day.hasSignal, let ratio = day.budgetRatio else { return [] }

        var out: [Contribution] = []

        // C1
        let c1 = budgetContribution(ratio: ratio)
        let over = day.minutesOverBudget
        out.append(Contribution(
            kind: .budget,
            value: c1,
            reason: over > 0
                ? "Over budget by \(over) min"
                : "\(day.distractingMinutes) min, under a \(day.budgetMinutes) min budget"
        ))

        // C2
        let sessions = min(day.focusSessionsCompleted, config.focusMaxSessions)
        if sessions > 0 {
            out.append(Contribution(
                kind: .focus,
                value: Double(sessions) * config.focusPerSession,
                reason: sessions == 1 ? "One focus session" : "\(sessions) focus sessions"
            ))
        }

        // C3
        let overrides = min(day.overridesTaken, config.overrideMaxCount)
        if overrides > 0 {
            out.append(Contribution(
                kind: .overrides,
                value: Double(overrides) * config.overridePenalty,
                reason: overrides == 1 ? "One override" : "\(overrides) overrides"
            ))
        }

        // C4 — all expected windows ran, and none was overridden.
        if day.scheduledWindowsExpected > 0,
           day.scheduledWindowsHonored >= day.scheduledWindowsExpected,
           day.overridesTaken == 0 {
            out.append(Contribution(
                kind: .schedule,
                value: config.scheduleBonus,
                reason: "Every scheduled block held"
            ))
        }

        // C5 — streak counted *including* today, since today is green here.
        if day.isGreen {
            let streakIncludingToday = context.streakBefore + 1
            let points = min(
                Double(streakIncludingToday / config.streakDaysPerPoint),
                config.streakMaxBonus
            )
            if points > 0 {
                out.append(Contribution(
                    kind: .streak,
                    value: points,
                    reason: "\(streakIncludingToday)-day streak"
                ))
            }
        }

        // C6 — break the despair spiral.
        if context.currentHealth < config.comebackThreshold, day.isGreen {
            out.append(Contribution(
                kind: .comeback,
                value: config.comebackBonus,
                reason: "Good day from a low place"
            ))
        }

        return out
    }

    // MARK: Commit

    public func evaluate(day: DayRecord, context: EvaluationContext) -> HealthEntry {
        let parts = contributions(for: day, context: context)
        let raw = parts.reduce(0) { $0 + $1.value }
        let clamped = min(max(raw, config.dailyClamp.lowerBound), config.dailyClamp.upperBound)
        // A no-signal day must move nothing, even though its raw sum is already 0.
        let delta = day.hasSignal ? clamped : 0

        let before = context.currentHealth
        let after = min(max(before + delta, 0), 100)

        let stageBefore = context.currentStage ?? BrainStage.raw(for: before)
        let stageAfter = BrainStage.resolved(
            health: after,
            previous: stageBefore,
            hysteresis: config.stageHysteresis
        )

        let streakAfter: Int = {
            guard day.hasSignal else { return context.streakBefore }  // a blind day neither breaks nor extends
            return day.isGreen ? context.streakBefore + 1 : 0
        }()

        return HealthEntry(
            date: day.date,
            healthBefore: before,
            healthAfter: after,
            contributions: parts,
            rawDelta: raw,
            delta: delta,
            wasClamped: day.hasSignal && raw != clamped,
            stageBefore: stageBefore,
            stageAfter: stageAfter,
            hadSignal: day.hasSignal,
            streakAfter: streakAfter
        )
    }

    /// The live, uncommitted delta shown during the day so the character reacts before
    /// the rollover. Same arithmetic, no persistence.
    public func provisionalDelta(day: DayRecord, context: EvaluationContext) -> Double {
        evaluate(day: day, context: context).delta
    }
}
