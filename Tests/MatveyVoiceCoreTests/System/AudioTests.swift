import Testing
import AVFoundation
@testable import MatveyVoiceCore

@Suite struct AudioTests {
    @Test func sampleBufferStopsAtLimit() {
        var b = SampleBuffer(maxSamples: 10)
        #expect(b.append([Float](repeating: 0.1, count: 6)) == false)
        #expect(b.append([Float](repeating: 0.1, count: 6)) == true)
        #expect(b.samples.count == 10)
        b.append([1, 2, 3])
        #expect(b.samples.count == 10)
    }

    @Test func fiveMinuteLimitIs4_8MillionSamples() {
        #expect(Int(AudioRecorder.maxDuration * AudioResampler.targetRate) == 4_800_000)
    }

    @Test func resamples48kStereoTo16kMono() throws {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 48_000)!
        buf.frameLength = 48_000  // 1 second
        for ch in 0..<2 {
            for i in 0..<48_000 { buf.floatChannelData![ch][i] = 0.5 * sinf(2 * .pi * 440 * Float(i) / 48_000) }
        }
        let rs = AudioResampler()
        let out = rs.convert(buf) + rs.flush()
        // 1 s at 16 kHz = 16000 samples (converter latency allows a small tolerance)
        #expect(abs(out.count - 16_000) < 200, "count \(out.count)")
        let peak = out.map(abs).max() ?? 0
        #expect(peak > 0.3 && peak < 0.7)
    }
}
