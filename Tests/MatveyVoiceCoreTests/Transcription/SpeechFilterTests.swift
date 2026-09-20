import Testing
import Foundation
@testable import MatveyVoiceCore

@Suite struct SpeechFilterTests {
    private func tone(amplitude: Float, seconds: Double = 1) -> [Float] {
        (0..<Int(16_000 * seconds)).map { amplitude * sin(Float($0) * 0.1) }
    }

    @Test func silenceAndNoiseFloorAreSilent() {
        #expect(SpeechFilter.isSilent([]))
        #expect(SpeechFilter.isSilent([Float](repeating: 0, count: 16_000)))
        #expect(SpeechFilter.isSilent(tone(amplitude: 0.001)))
        #expect(SpeechFilter.isSilent(tone(amplitude: 0.5, seconds: 0.05)))
    }

    @Test func audibleSignalIsNotSilent() {
        #expect(!SpeechFilter.isSilent(tone(amplitude: 0.2)))
    }

    @Test(arguments: [
        "Субтитры сделал DimaTorzok",
        "Субтитры создавал DimaTorzok.",
        "Продолжение следует...",
        "Спасибо за просмотр!",
        "Thanks for watching!",
        "Thank you for watching.",
        "Subtitles by the Amara.org community",
        "[Music]", "(музыка)", "*applause*", "   ", "...",
        "Редактор субтитров А.Семкин", "Корректор А.Егорова",
    ])
    func knownHallucinationsAreDetected(_ text: String) {
        #expect(SpeechFilter.isHallucination(text))
    }

    @Test(arguments: [
        "Привет, как дела?",
        "Send the subtitles to Anna tomorrow morning please",
        "Thank you, see you tomorrow",
        "Продолжение следует в понедельник, когда вернётся Андрей",
        "Открой Telegram",
        "Субтитры готовы к отправке",
        "Корректор поправил текст",
        "Music is playing loud",
        "Music", "Музыка", "You", "Bye", "Тишина",
        "(смеётся) я так рад, что ты пришёл сюда сегодня вечером (шутка)",
    ])
    func realSpeechIsKept(_ text: String) {
        #expect(!SpeechFilter.isHallucination(text))
    }
}
