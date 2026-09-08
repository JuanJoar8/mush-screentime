import Foundation

/// Sound for a focus session — synthesised, never shipped as audio files.
///
/// Opal sells soundscapes; ours are generated a sample at a time. That is not thrift: a
/// loop long enough not to be noticeable is tens of megabytes, and a short one is worse
/// than silence because the ear finds the seam within a minute and then cannot unhear it.
/// Noise generated live has no seam at all.
///
/// The maths lives in `MushKit` so it can be tested without an audio engine. The engine
/// itself is in the app target.
public enum Soundscape: String, Codable, Sendable, CaseIterable, Identifiable {
    case off
    /// Brown noise: energy falling 6 dB per octave. Deep, close, like a room with weather
    /// outside it.
    case room
    /// Pink noise: 3 dB per octave. Brighter — the texture of steady rain.
    case rain
    /// Brown noise under a slow low-frequency swell, so it breathes rather than sits.
    case tide

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Off"
        case .room: "Room"
        case .rain: "Rain"
        case .tide: "Tide"
        }
    }

    /// Plain description of what is actually being made. No "immersive", no "curated".
    public var explanation: String {
        switch self {
        case .off: "Silence."
        case .room: "Deep noise, generated live. No loop to notice."
        case .rain: "Brighter noise, closer to rain than to a fan."
        case .tide: "Deep noise that swells slowly, about six seconds a cycle."
        }
    }

    public var isSilent: Bool { self == .off }
}

/// Generates the sample stream, deterministically.
///
/// Deterministic on purpose: given a seed, the same samples every time, so the shape of
/// the output can be asserted in a test rather than listened to and hoped about.
public struct NoiseGenerator: Sendable {
    public let soundscape: Soundscape
    public let sampleRate: Double

    private var state: UInt64
    /// Running integrator for brown noise, and the first pink filter pole.
    private var brown: Double = 0
    private var pinkA: Double = 0
    private var pinkB: Double = 0
    private var pinkC: Double = 0
    private var phase: Double = 0

    public init(soundscape: Soundscape, sampleRate: Double = 48_000, seed: UInt64 = 0x2545F491) {
        self.soundscape = soundscape
        self.sampleRate = sampleRate
        self.state = seed == 0 ? 0x2545F491 : seed
    }

    /// xorshift64. Cheap enough for the audio thread, which is the only requirement that
    /// matters here — this runs a few hundred thousand times a second.
    private mutating func white() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        // Top 32 bits mapped to -1...1.
        return Double(Int32(truncatingIfNeeded: state >> 32)) / Double(Int32.max)
    }

    /// One sample, in -1...1.
    public mutating func next() -> Double {
        guard !soundscape.isSilent else { return 0 }
        let w = white()

        switch soundscape {
        case .off:
            return 0

        case .room, .tide:
            // Leaky integrator: brown noise. The leak keeps it from wandering off to a
            // DC offset over minutes, which a pure integrator does.
            brown = (brown + 0.02 * w) * 0.998
            var sample = brown * 8

            if soundscape == .tide {
                // A slow swell, six seconds a cycle, never below half volume — a
                // soundscape that fades to nothing reads as a fault.
                phase += 2 * .pi / (sampleRate * 6)
                if phase > 2 * .pi { phase -= 2 * .pi }
                sample *= 0.75 + 0.25 * sin(phase)
            }
            return max(-1, min(1, sample))

        case .rain:
            // Three-pole approximation of pink noise (Paul Kellet's method). Cheap, and
            // close enough that the ear cannot tell it from the real thing.
            pinkA = 0.99765 * pinkA + w * 0.0990460
            pinkB = 0.96300 * pinkB + w * 0.2965164
            pinkC = 0.57000 * pinkC + w * 1.0526913
            let sample = (pinkA + pinkB + pinkC + w * 0.1848) * 0.20
            return max(-1, min(1, sample))
        }
    }

    /// Fill a buffer. Returns it, for the tests.
    public mutating func fill(_ count: Int) -> [Double] {
        var out = [Double]()
        out.reserveCapacity(count)
        for _ in 0..<count { out.append(next()) }
        return out
    }
}

public extension Array where Element == Double {
    /// RMS level. The one number that says whether a stream is audible and not clipping.
    var rootMeanSquare: Double {
        guard !isEmpty else { return 0 }
        return (reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
    }
}
