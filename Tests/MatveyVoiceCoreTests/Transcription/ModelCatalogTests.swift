import Testing
import Foundation
@testable import MatveyVoiceCore

@Suite struct ModelCatalogTests {
    @Test func mapsSettingsIDsToWhisperKitFolders() {
        #expect(ModelCatalog.whisperKitVariant(for: "small") == "openai_whisper-small")
        #expect(ModelCatalog.whisperKitVariant(for: "large-v3-turbo") == "openai_whisper-large-v3-v20240930_turbo")
        #expect(ModelCatalog.whisperKitVariant(for: "nope") == nil)
    }

    @Test func errorsBecomeHumanReasons() {
        let offline = TranscriptionErrorDescriber.reason(for: URLError(.notConnectedToInternet))
        let dropped = TranscriptionErrorDescriber.reason(for: URLError(.networkConnectionLost))
        let space = TranscriptionErrorDescriber.reason(for: CocoaError(.fileWriteOutOfSpace))
        #expect(offline.localizedCaseInsensitiveContains("internet"))
        #expect(dropped.localizedCaseInsensitiveContains("interrupted"))
        #expect(space.localizedCaseInsensitiveContains("space"))
        #expect(Set([offline, dropped, space]).count == 3)
    }
}
