import Foundation
import AVFoundation

public enum AudioRecorderError: Error, Sendable {
    case alreadyRecording
    case noInput
    case engineFailed(String)
}

/// Records the microphone into memory as 16 kHz mono Float. Nothing touches disk.
public final class AudioRecorder: AudioRecording, @unchecked Sendable {
    public static let maxDuration: TimeInterval = 300

    /// Called once when the 5 minute limit stops the recording by itself.
    /// Invoked on an audio thread; hop to the main actor if needed.
    public var onLimitReached: (@Sendable () -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onLimit }
        set { lock.lock(); _onLimit = newValue; lock.unlock() }
    }

    private let lock = NSLock()
    private var _onLimit: (@Sendable () -> Void)?
    private var engine: AVAudioEngine?
    private var buffer = SampleBuffer(maxSamples: Int(AudioRecorder.maxDuration * AudioResampler.targetRate))
    private var continuation: AsyncStream<Float>.Continuation?
    private var _levels: AsyncStream<Float>
    private var limitFired = false
    private var resampler: AudioResampler?

    public init() {
        var cont: AsyncStream<Float>.Continuation!
        _levels = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { cont = $0 }
        continuation = cont
    }

    /// Normalised 0...1 loudness, roughly 20 updates per second.
    public var levels: AsyncStream<Float> {
        lock.lock(); defer { lock.unlock() }
        return _levels
    }

    public func start() throws {
        lock.lock()
        if engine != nil { lock.unlock(); throw AudioRecorderError.alreadyRecording }
        buffer = SampleBuffer(maxSamples: Int(Self.maxDuration * AudioResampler.targetRate))
        limitFired = false
        lock.unlock()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioRecorderError.noInput }
        let resampler = AudioResampler()
        lock.lock(); self.resampler = resampler; lock.unlock()
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] pcm, _ in
            guard let self else { return }
            let samples = resampler.convert(pcm)
            self.consume(samples)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioRecorderError.engineFailed(error.localizedDescription)
        }
        lock.lock(); self.engine = engine; lock.unlock()
    }

    public func stop() -> RecordedAudio {
        lock.lock()
        let engine = self.engine
        self.engine = nil
        lock.unlock()
        halt(engine)
        lock.lock()
        let tail = resampler?.flush() ?? []
        resampler = nil
        buffer.append(tail)
        let samples = buffer.samples
        lock.unlock()
        return RecordedAudio(samples: samples, duration: Double(samples.count) / AudioResampler.targetRate)
    }

    private func halt(_ engine: AVAudioEngine?) {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func consume(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        var sum: Float = 0
        for s in samples { sum += s * s }
        let rms = (sum / Float(samples.count)).squareRoot()
        // -50 dB .. 0 dB mapped to 0...1
        let db = 20 * log10(max(rms, 1e-6))
        let level = min(max((db + 50) / 50, 0), 1)

        lock.lock()
        let full = buffer.append(samples)
        let fire = full && !limitFired
        if fire { limitFired = true }
        let cont = continuation
        let callback = _onLimit
        let engineToStop = fire ? engine : nil
        lock.unlock()

        cont?.yield(level)
        if fire {
            // Stop capturing; stop() later still returns what was recorded.
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let e = self.engine
                self.engine = nil
                self.lock.unlock()
                self.halt(e ?? engineToStop)
                callback?()
            }
        }
    }
}
