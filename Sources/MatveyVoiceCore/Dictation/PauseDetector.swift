import Foundation

/// Pure check on the tail of a recording: did the speaker just stop talking?
/// Used for voice send without holding a key — the tail is transcribed only at such pauses.
public enum PauseDetector {
    static let frameSamples = 800  // 50 ms at 16 kHz
    public static let pauseDuration: TimeInterval = 0.7
    /// Below this the loudest frame is not speech at all.
    static let minimumSpeechRMS: Float = 0.01
    /// A pause frame is this much quieter than the speech before it (relative, so a noisy room works).
    static let quietRatio: Float = 0.2

    public static func endsWithPauseAfterSpeech(_ samples: [Float], sampleRate: Double = 16_000) -> Bool {
        let frames = stride(from: 0, to: samples.count - frameSamples + 1, by: frameSamples).map { start in
            let frame = samples[start..<start + frameSamples]
            return (frame.reduce(0) { $0 + $1 * $1 } / Float(frameSamples)).squareRoot()
        }
        let pauseFrames = Int(pauseDuration * sampleRate) / frameSamples
        guard frames.count > pauseFrames, let speech = frames.dropLast(pauseFrames).max(),
              speech >= minimumSpeechRMS else { return false }
        return frames.suffix(pauseFrames).allSatisfy { $0 < speech * quietRatio }
    }
}
