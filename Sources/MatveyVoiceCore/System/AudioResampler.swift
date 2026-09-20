import Foundation
import AVFoundation

/// Converts arbitrary input buffers to 16 kHz mono Float samples (in memory only).
public final class AudioResampler {
    public static let targetRate: Double = 16_000
    private let target: AVAudioFormat
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?

    public init() {
        target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.targetRate,
                               channels: 1, interleaved: false)!
    }

    public func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        if converter == nil || sourceFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
            sourceFormat = buffer.format
        }
        guard let converter else { return [] }
        let ratio = Self.targetRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return [] }
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let input = buffer
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if supplied { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, error == nil, let data = out.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(out.frameLength)))
    }

    /// Drains the samples the converter still holds (its filter latency); call once at the end.
    public func flush() -> [Float] {
        guard let converter, let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 4096) else { return [] }
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            inputStatus.pointee = .endOfStream
            return nil
        }
        guard status != .error, error == nil, let data = out.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(out.frameLength)))
    }
}

/// Bounded in-memory sample store; reports when the recording limit is hit.
public struct SampleBuffer: Sendable {
    public let maxSamples: Int
    public private(set) var samples: [Float] = []
    public var isFull: Bool { samples.count >= maxSamples }

    public init(maxSamples: Int) { self.maxSamples = maxSamples }

    /// Appends up to the limit. Returns true if the limit has been reached.
    @discardableResult
    public mutating func append(_ new: [Float]) -> Bool {
        let room = maxSamples - samples.count
        if room > 0 { samples.append(contentsOf: new.prefix(room)) }
        return isFull
    }
}
