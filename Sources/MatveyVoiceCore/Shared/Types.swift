import Foundation

public enum Hotkey: String, Codable, Sendable, CaseIterable {
    case rightOption, rightCommand, rightControl, fn
}

public enum TriggerMode: String, Codable, Sendable, CaseIterable {
    case hold, toggle
}

public enum Language: String, Codable, Sendable, CaseIterable {
    case auto, ru, en
}

public struct RecordedAudio: Sendable, Equatable {
    /// 16 kHz mono samples.
    public var samples: [Float]
    public var duration: TimeInterval
    public init(samples: [Float], duration: TimeInterval) {
        self.samples = samples
        self.duration = duration
    }
}

public struct Transcription: Sendable, Equatable {
    public var text: String
    public var detectedLanguage: String?
    public init(text: String, detectedLanguage: String? = nil) {
        self.text = text
        self.detectedLanguage = detectedLanguage
    }
}

public enum ModelState: Sendable, Equatable {
    case notInstalled
    case downloading(progress: Double)
    case preparing
    case ready
    case failed(reason: String)
}

public enum InsertResult: Sendable, Equatable {
    case inserted
    case copiedOnly(reason: String)
}

public enum PermissionKind: String, Sendable, CaseIterable {
    case microphone
    case accessibility
}

public enum PermissionState: Sendable, Equatable {
    case notDetermined, granted, denied
}

public struct PermissionsStatus: Sendable, Equatable {
    public var microphone: PermissionState
    public var accessibility: PermissionState
    public init(microphone: PermissionState = .notDetermined, accessibility: PermissionState = .notDetermined) {
        self.microphone = microphone
        self.accessibility = accessibility
    }
}

public enum DictationState: Sendable, Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case message(text: String)
}
