import Foundation

/// Single place mapping `AppSettings.modelID` to WhisperKit model folder names
/// (repo argmaxinc/whisperkit-coreml) and approximate download sizes.
public enum ModelCatalog {
    public struct Entry: Sendable, Equatable {
        public let modelID: String
        public let whisperKitVariant: String
        public let approximateMegabytes: Int
    }

    public static let entries: [Entry] = [
        Entry(modelID: "small", whisperKitVariant: "openai_whisper-small", approximateMegabytes: 250),
        Entry(modelID: "large-v3-turbo", whisperKitVariant: "openai_whisper-large-v3-v20240930_turbo", approximateMegabytes: 630),
    ]

    public static func entry(for modelID: String) -> Entry? {
        entries.first { $0.modelID == modelID }
    }

    public static func whisperKitVariant(for modelID: String) -> String? {
        entry(for: modelID)?.whisperKitVariant
    }
}
