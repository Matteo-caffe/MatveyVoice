import Testing
import Foundation
import AVFoundation
@testable import MatveyVoiceCore

/// Manual check with a real model. Skipped unless MATVEY_LIVE_DIR points to a folder
/// containing ru.wav and en.wav (16 kHz mono float). Downloads the `small` model (~250 MB)
/// into MATVEY_LIVE_DIR/models. Recognized text goes to the console only. Not part of the automatic run.
@Suite struct LiveModelTests {
    static let dir = ProcessInfo.processInfo.environment["MATVEY_LIVE_DIR"]

    private func load(_ url: URL) throws -> RecordedAudio {
        let file = try AVAudioFile(forReading: url)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        let samples = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))
        return RecordedAudio(samples: samples, duration: Double(samples.count) / 16_000)
    }

    @Test(.enabled(if: dir != nil)) func smallModelTranscribesRuAndEn() async throws {
        let dir = URL(fileURLWithPath: Self.dir!)
        let t = WhisperTranscriber(downloadBase: dir.appendingPathComponent("models"))
        await t.prepare(modelID: "small")
        #expect(t.state == .ready)
        let ru = try await t.transcribe(load(dir.appendingPathComponent("ru.wav")), language: .auto, hints: [])
        let en = try await t.transcribe(load(dir.appendingPathComponent("en.wav")), language: .auto, hints: ["Anna"])
        print("LIVE RU[\(ru?.detectedLanguage ?? "-")]: \(ru?.text ?? "nil")\nLIVE EN[\(en?.detectedLanguage ?? "-")]: \(en?.text ?? "nil")")
        #expect(ru != nil && en != nil)
    }
}
