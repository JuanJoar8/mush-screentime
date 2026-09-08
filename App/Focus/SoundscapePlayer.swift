import AVFoundation
import Foundation
import MushKit

/// Plays a `Soundscape` by generating it, sample by sample, on the audio thread.
///
/// No audio files ship with the app. `NoiseGenerator` in `MushKit` holds the maths and is
/// unit-tested; this type is only the plumbing that hands samples to `AVAudioEngine`.
///
/// **The render block is a real-time context.** It cannot allocate, lock, or call
/// Swift runtime machinery that might. So the generator is held in an
/// `UnsafeMutablePointer` and mutated in place — the one place in this project where
/// that is the right tool rather than a shortcut.
@MainActor
final class SoundscapePlayer {
    static let shared = SoundscapePlayer()

    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var generator: UnsafeMutablePointer<NoiseGenerator>?

    private(set) var current: Soundscape = .off

    private init() {}

    func play(_ soundscape: Soundscape) {
        guard soundscape != current else { return }
        stop()
        guard !soundscape.isSilent else { return }

        // `.playback` with `.mixWithOthers`: a focus session should sit under a podcast or
        // music rather than seizing the output. Silencing what the user chose to hear is
        // not our call to make.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)

        let pointer = UnsafeMutablePointer<NoiseGenerator>.allocate(capacity: 1)
        pointer.initialize(to: NoiseGenerator(soundscape: soundscape, sampleRate: format.sampleRate))

        let source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = Float(pointer.pointee.next())
                for buffer in buffers {
                    let data = buffer.mData!.assumingMemoryBound(to: Float.self)
                    data[frame] = value
                }
            }
            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        // Headroom. Noise at full scale is unpleasant and, over an hour, harmful.
        engine.mainMixerNode.outputVolume = 0.22

        do {
            try engine.start()
        } catch {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
            return
        }

        self.engine = engine
        self.source = source
        self.generator = pointer
        self.current = soundscape
    }

    func stop() {
        engine?.stop()
        if let source { engine?.detach(source) }
        engine = nil
        source = nil

        if let generator {
            generator.deinitialize(count: 1)
            generator.deallocate()
        }
        generator = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        current = .off
    }
}
