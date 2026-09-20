import Foundation
import Testing

@Suite struct LocalizationTests {
    private func keys(_ lang: String, _ table: String) throws -> Set<String> {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        url.appendPathComponent("Resources/\(lang).lproj/\(table).strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return Set(dict.keys)
    }

    @Test(arguments: ["Dictation", "Transcription", "System", "UI"])
    func englishAndRussianKeysMatch(table: String) throws {
        let en = try keys("en", table)
        let ru = try keys("ru", table)
        #expect(!en.isEmpty)
        #expect(en.subtracting(ru).isEmpty, "missing in ru: \(en.subtracting(ru))")
        #expect(ru.subtracting(en).isEmpty, "missing in en: \(ru.subtracting(en))")
    }
}
