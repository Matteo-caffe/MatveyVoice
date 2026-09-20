import Foundation

/// Pure text cleanup applied after recognition.
public enum TextPostProcessor {
    /// Standalone fillers: э, эм, ээ, э-э, uh, um (any case), as whole words only.
    private static let fillerPattern = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}_])(?<![\p{L}\p{N}]-)(?:э+(?:-э+)*м*|uh+|um+)(?![\p{L}\p{N}_]|-[\p{L}\p{N}])(?:[ \t]*,)?"#,
        options: [.caseInsensitive]
    )

    public static func process(_ text: String, removeFillers: Bool) -> String {
        guard removeFillers else { return text }
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = NSRange(result.startIndex..., in: result)
        guard fillerPattern.firstMatch(in: result, range: full) != nil else { return result }

        let mutable = NSMutableString(string: result)
        for match in fillerPattern.matches(in: result, range: full).reversed() {
            let loc = match.range.location
            let before = mutable.substring(to: loc).trimmingCharacters(in: .whitespacesAndNewlines)
            let atSentenceStart = before.isEmpty || ".!?…".contains(before.last!)
            mutable.deleteCharacters(in: match.range)
            if atSentenceStart { capitalizeNextLetter(in: mutable, from: loc) }
        }
        result = mutable as String

        result = replace(#"\s+"#, in: result, with: " ")
        result = replace(#",(\s*,)+"#, in: result, with: ",")     // ", ," -> ","
        result = replace(#"\s+([,.!?…;:])"#, in: result, with: "$1") // " ," -> ","
        result = replace(#",\s*([.!?…;:])"#, in: result, with: "$1") // ",." -> "."
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = replace(#"^[,;:\s]+"#, in: result, with: "")

        if result.rangeOfCharacter(from: .alphanumerics) == nil { return "" }
        return result
    }

    private static func capitalizeNextLetter(in text: NSMutableString, from location: Int) {
        var i = location
        while i < text.length {
            let range = text.rangeOfComposedCharacterSequence(at: i)
            let ch = text.substring(with: range)
            if ch.rangeOfCharacter(from: .letters) != nil {
                text.replaceCharacters(in: range, with: ch.uppercased())
                return
            }
            if ch.rangeOfCharacter(from: .whitespaces.union(CharacterSet(charactersIn: ",;:"))) == nil { return }
            i = range.location + range.length
        }
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}
