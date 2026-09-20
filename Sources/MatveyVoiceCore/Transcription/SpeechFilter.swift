import Foundation

/// Pure functions that decide whether a recording or a result contains no real speech.
public enum SpeechFilter {
    /// Recordings shorter than this (in samples at 16 kHz) are treated as silence.
    static let minimumSamples = 1_600
    static let minimumPeak: Float = 0.01
    static let minimumRMS: Float = 0.002

    public static func isSilent(_ samples: [Float]) -> Bool {
        guard samples.count >= minimumSamples else { return true }
        var peak: Float = 0
        var sum: Double = 0
        for s in samples {
            let a = abs(s)
            if a > peak { peak = a }
            sum += Double(s) * Double(s)
        }
        let rms = Float((sum / Double(samples.count)).squareRoot())
        return peak < minimumPeak || rms < minimumRMS
    }

    /// Whole-text phrases Whisper invents on silence (normalized form). Plain single words are never listed.
    static let hallucinationPhrases: Set<String> = [
        "продолжение следует", "спасибо за просмотр", "спасибо за внимание",
        "подписывайтесь на канал", "подписывайтесь на мой канал", "до новых встреч", "до скорой встречи",
        "subtitles by the amara org community", "thanks for watching", "thank you for watching",
        "thanks for listening", "please subscribe", "please subscribe to my channel",
        "subscribe to my channel", "see you in the next video", "see you next time",
        "like and subscribe", "blank audio",
    ]

    /// Credit phrases followed by a short name (at most two capitalized words).
    static let creditStems: [String] = [
        "субтитры сделал", "субтитры делал", "субтитры создавал", "субтитры подогнал", "субтитры добавил",
        "редактор субтитров", "корректор",
        "subtitles by", "subtitled by", "captions by",
    ]
    static let maxCreditNameWords = 2
    static let maxAnnotationWords = 4

    /// Words split on anything that is not a letter or digit, original case kept.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
    }

    static func normalize(_ text: String) -> String {
        words(text).map { $0.lowercased() }.joined(separator: " ")
    }

    public static func isHallucination(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = words(trimmed)
        if original.isEmpty { return true }
        // A short sound annotation entirely in brackets: [music], (музыка), *applause*.
        if let first = trimmed.first, let last = trimmed.last, trimmed.count > 1,
           ["[": "]", "(": ")", "*": "*", "♪": "♪"][first] == last,
           !trimmed.dropFirst().dropLast().contains(where: { "])*♪".contains($0) }),
           original.count <= maxAnnotationWords {
            return true
        }
        let lowered = original.map { $0.lowercased() }
        let n = lowered.joined(separator: " ")
        if hallucinationPhrases.contains(n) { return true }
        for stem in creditStems {
            let stemWords = stem.split(separator: " ").map(String.init)
            guard lowered.starts(with: stemWords) else { continue }
            let name = original.dropFirst(stemWords.count)
            if name.count <= maxCreditNameWords,
               name.allSatisfy({ $0.first.map { $0.isUppercase || $0.isNumber } ?? false }) {
                return true
            }
        }
        return false
    }
}
