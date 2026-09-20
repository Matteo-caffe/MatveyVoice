import Foundation
import Testing
@testable import MatveyVoiceCore

@MainActor
struct AppSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "MatveyVoiceTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsMatchSpec() {
        let s = AppSettings(defaults: freshDefaults())
        #expect(s.hotkey == .rightOption)
        #expect(s.triggerMode == .hold)
        #expect(s.language == .auto)
        #expect(s.modelID == "large-v3-turbo")
        #expect(s.removeFillers == true)
        #expect(s.launchAtLogin == false)
        #expect(s.dictionary.isEmpty)
    }

    @Test func valuesSurviveRestart() {
        let d = freshDefaults()
        let a = AppSettings(defaults: d)
        a.hotkey = .fn
        a.triggerMode = .toggle
        a.language = .ru
        a.modelID = "small"
        a.dictionary = ["Матвей", "WhisperKit"]
        a.removeFillers = false
        a.launchAtLogin = true

        let b = AppSettings(defaults: d)
        #expect(b.hotkey == .fn)
        #expect(b.triggerMode == .toggle)
        #expect(b.language == .ru)
        #expect(b.modelID == "small")
        #expect(b.dictionary == ["Матвей", "WhisperKit"])
        #expect(b.removeFillers == false)
        #expect(b.launchAtLogin == true)
    }
}
