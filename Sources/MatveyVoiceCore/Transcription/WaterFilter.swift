import Foundation

/// Pure removal of spoken "water" after the hesitation sounds are gone: filler words and phrases
/// (ну, короче, типа, вот так вот, like, you know…), sentences made only of them, and stutters
/// (я я думаю). Many of these words also have a real meaning (вот почему, это значит, сделай
/// короче, в общем чате, как бы не опоздать), so a filler is removed only where it is clearly a
/// filler: set off by commas, as a whole sentence, or — for the few that are almost never
/// meaningful there — at the start of a sentence.
enum WaterFilter {
    /// Removed when set off by commas: «Ну, …», «…, типа, …», «…, вот.».
    static let parenthetical = [
        "ну", "вот", "ну вот", "так вот", "вот так вот", "короче", "короче говоря", "типа", "в общем",
        "в общем-то", "как бы", "это самое", "так сказать", "скажем так", "значит", "собственно",
        "собственно говоря", "получается", "в принципе", "то есть", "блин", "понимаешь", "знаешь",
        "like", "you know", "i mean", "basically", "kind of", "sort of", "well", "so", "you see",
    ]
    /// Removed at the start of a sentence even without a comma (not in questions: «Ну и что?»).
    static let leading = ["ну", "ну вот", "так вот", "вот так вот", "короче", "типа", "в общем-то"]
    /// A sentence made only of these (and the parenthetical ones) is dropped: «Вот так вот.», «Как-то так.».
    static let sentenceOnly = ["так", "вот так", "как-то так", "вот как-то так", "ну как-то так", "такие дела",
                               "вот такие дела", "типа того", "ну типа того", "so yeah"]
    /// After a removed filler the comma stays before these: «Я пришёл, типа, а там…» → «Я пришёл, а там…».
    static let conjunctions: Set<String> = [
        "а", "но", "и", "или", "что", "чтобы", "потому", "поэтому", "который", "которая", "которое",
        "которые", "которого", "которой", "которым", "когда", "если", "где", "куда", "как", "хотя",
        "пока", "ведь", "зато", "однако", "чем", "and", "but", "or", "because", "which", "who", "that",
        "when", "if", "so", "while", "although", "where",
    ]
    /// Repeated on purpose: «да да», «очень очень», «that that».
    static let intentionalRepeats: Set<String> = [
        "да", "нет", "так", "очень", "ой", "ах", "ха", "хи", "хо", "давай", "иди", "беги", "скорее",
        "быстрее", "тук", "бла", "ура", "пока", "привет", "yes", "no", "very", "bye", "ha", "go", "hey",
        "ok", "okay", "bla", "knock", "that", "had", "many", "much",
    ]

    static func clean(_ text: String) -> String {
        var result = ""
        for piece in sentences(text) {
            let body = piece.drop(while: \.isWhitespace)
            let cleaned = cleanSentence(String(body))
            guard !cleaned.isEmpty else { continue }
            result += (result.isEmpty ? "" : String(piece.prefix(while: \.isWhitespace))) + cleaned
        }
        return result
    }

    // MARK: предложение

    private static func cleanSentence(_ sentence: String) -> String {
        guard !isFillerOnly(sentence) else { return "" }
        var s = sentence
        let startsUpper = s.first?.isUppercase ?? false
        var strippedLeading = false
        let question = s.trimmingCharacters(in: .whitespaces).hasSuffix("?")
        while let rest = stripLeading(s, allowWithoutComma: !question) {
            s = rest
            strippedLeading = true
        }
        s = replaceAll(trailingPattern, in: s, with: "")
        s = removeMiddle(s)
        s = collapseRepeats(s)
        guard !isFillerOnly(s), s.contains(where: { $0.isLetter || $0.isNumber }) else { return "" }
        if strippedLeading && startsUpper, let first = s.firstIndex(where: \.isLetter) {
            s.replaceSubrange(first...first, with: s[first].uppercased())
        }
        return s
    }

    /// Pieces ending with . ! ? … (the last one may have no ending); each keeps its leading spaces.
    private static func sentences(_ text: String) -> [Substring] {
        let regex = try! NSRegularExpression(pattern: #"[^.!?…]+[.!?…]*|[.!?…]+"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { text[$0] } }
    }

    private static func words(_ s: String) -> [String] {
        s.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "-") }).map(String.init)
    }

    /// Only filler words and no question or exclamation: «Вот так вот.», «Ну вот», «Как-то так…».
    private static func isFillerOnly(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("?") || trimmed.hasSuffix("!") { return false }
        var rest = words(trimmed)
        guard !rest.isEmpty else { return false }
        let phrases = (parenthetical + sentenceOnly).map { $0.split(separator: " ").map(String.init) }
            .sorted { $0.count > $1.count }
        while !rest.isEmpty {
            guard let phrase = phrases.first(where: { rest.starts(with: $0) }) else { return false }
            rest.removeFirst(phrase.count)
        }
        return true
    }

    // MARK: шаблоны

    private static func alternation(_ phrases: [String]) -> String {
        phrases.sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: #"\s+"#) }
            .joined(separator: "|")
    }

    private static let leadingWithComma = try! NSRegularExpression(
        pattern: #"^\s*(?:\#(alternation(parenthetical)))\s*,\s*"#, options: [.caseInsensitive])
    private static let leadingWithoutComma = try! NSRegularExpression(
        pattern: #"^\s*(?:\#(alternation(leading)))(?![\p{L}\p{N}-])\s*,?\s*"#, options: [.caseInsensitive])
    private static let trailingPattern = try! NSRegularExpression(
        pattern: #"(?:\s*,\s*(?:\#(alternation(parenthetical))))+(?=\s*[.!?…]*\s*$)"#, options: [.caseInsensitive])
    private static let middlePattern = try! NSRegularExpression(
        pattern: #"\s*,\s*(?:\#(alternation(parenthetical)))\s*,\s*(?=([\p{L}\p{N}]+))"#, options: [.caseInsensitive])
    /// A word or two-word phrase said again right away: «я я», «что это что это», «мы пойдём, мы пойдём».
    private static let repeatPattern = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}-])(\p{L}+(?:[ \t]+\p{L}+)?)(?:[ \t]*,?[ \t]+\1)+(?![\p{L}\p{N}-])"#,
        options: [.caseInsensitive])

    private static func stripLeading(_ s: String, allowWithoutComma: Bool) -> String? {
        let range = NSRange(s.startIndex..., in: s)
        for regex in allowWithoutComma ? [leadingWithComma, leadingWithoutComma] : [leadingWithComma] {
            if let m = regex.firstMatch(in: s, range: range), m.range.length > 0, let r = Range(m.range, in: s) {
                let rest = String(s[r.upperBound...])
                return rest.contains(where: \.isLetter) || rest.contains(where: \.isNumber) ? rest : nil
            }
        }
        return nil
    }

    /// «, типа, » → «, » before a conjunction (the comma belongs to the sentence), otherwise « ».
    private static func removeMiddle(_ s: String) -> String {
        let text = NSMutableString(string: s)
        var changed = true
        while changed {
            changed = false
            let current = text as String
            guard let m = middlePattern.firstMatch(in: current, range: NSRange(location: 0, length: text.length)) else { break }
            let next = text.substring(with: m.range(at: 1)).lowercased()
            text.replaceCharacters(in: m.range, with: conjunctions.contains(next) ? ", " : " ")
            changed = true
        }
        return text as String
    }

    private static func collapseRepeats(_ s: String) -> String {
        var current = s
        for _ in 0..<5 {
            let text = NSMutableString(string: current)
            for m in repeatPattern.matches(in: current, range: NSRange(location: 0, length: text.length)).reversed() {
                let phrase = text.substring(with: m.range(at: 1))
                if phrase.split(separator: " ").allSatisfy({ intentionalRepeats.contains($0.lowercased()) }) { continue }
                text.replaceCharacters(in: m.range, with: phrase)
            }
            if text as String == current { break }
            current = text as String
        }
        return current
    }

    private static func replaceAll(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
