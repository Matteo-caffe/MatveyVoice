import Testing
@testable import MatveyVoiceCore

@Suite struct TextPostProcessorTests {
    @Test func removesStandaloneFillersInBothLanguages() {
        #expect(TextPostProcessor.process("Я э думаю эм что ээ да", removeFillers: true) == "Я думаю что да")
        #expect(TextPostProcessor.process("So uh I think um yes", removeFillers: true) == "So I think yes")
    }

    @Test func isCaseInsensitive() {
        #expect(TextPostProcessor.process("well UM okay Uh", removeFillers: true) == "well okay")
    }

    @Test func leavesOrdinaryWordsAndWordParts() {
        let text = "Ну, like, это эмоции, umbrella и uhura, эхо"
        #expect(TextPostProcessor.process(text, removeFillers: true) == text)
    }

    @Test func cleansCommasAroundRemovedFiller() {
        #expect(TextPostProcessor.process("Ну, э, я думаю", removeFillers: true) == "Ну, я думаю")
        #expect(TextPostProcessor.process("Я думаю, эм.", removeFillers: true) == "Я думаю.")
        #expect(TextPostProcessor.process("Well, um, yes", removeFillers: true) == "Well, yes")
    }

    @Test func fillerAtStartCapitalizesNextWord() {
        #expect(TextPostProcessor.process("Э, привет", removeFillers: true) == "Привет")
        #expect(TextPostProcessor.process("Um, hello there", removeFillers: true) == "Hello there")
    }

    @Test func returnsTextUntouchedWhenDisabled() {
        let text = "  э  привет um "
        #expect(TextPostProcessor.process(text, removeFillers: false) == text)
    }

    @Test func trimsEdgesAndAllFillerTextBecomesEmpty() {
        #expect(TextPostProcessor.process("  привет  ", removeFillers: true) == "привет")
        #expect(TextPostProcessor.process("Э-э", removeFillers: true) == "")
        #expect(TextPostProcessor.process("Эм... um", removeFillers: true) == "")
    }

    @Test func hyphenatedInterjectionsAreNotMangled() {
        #expect(TextPostProcessor.process("Uh-huh, right", removeFillers: true) == "Uh-huh, right")
        #expect(TextPostProcessor.process("Yes um-hmm sure", removeFillers: true) == "Yes um-hmm sure")
    }

    @Test func nextWordAfterSentenceEndIsCapitalized() {
        #expect(TextPostProcessor.process("Привет. Э, как дела", removeFillers: true) == "Привет. Как дела")
        #expect(TextPostProcessor.process("Done! Um so what next?", removeFillers: true) == "Done! So what next?")
    }

    @Test func extractSendCommandStripsTrailingKeywordAndKeepsSentencePunctuation() {
        let r = TextPostProcessor.extractSendCommand("Привет, как дела? Отправить", keyword: "отправить")
        #expect(r.text == "Привет, как дела?")
        #expect(r.shouldSend)
    }

    @Test func extractSendCommandIsCaseInsensitiveAndAllowsTrailingPunctuation() {
        let r = TextPostProcessor.extractSendCommand("hello world SEND.", keyword: "send")
        #expect(r.text == "hello world")
        #expect(r.shouldSend)
    }

    @Test func extractSendCommandRequiresWholeWordMatch() {
        let r = TextPostProcessor.extractSendCommand("хочу переотправить", keyword: "отправить")
        #expect(r.text == "хочу переотправить")
        #expect(!r.shouldSend)
    }

    @Test func extractSendCommandIgnoresKeywordNotAtEnd() {
        let r = TextPostProcessor.extractSendCommand("send hello world", keyword: "send")
        #expect(r.text == "send hello world")
        #expect(!r.shouldSend)
    }

    @Test func extractSendCommandWithEmptyKeywordNeverMatches() {
        let r = TextPostProcessor.extractSendCommand("hello send", keyword: "")
        #expect(r.text == "hello send")
        #expect(!r.shouldSend)
    }

    @Test func extractSendCommandWithOnlyTheKeywordLeavesEmptyText() {
        let r = TextPostProcessor.extractSendCommand("Send", keyword: "send")
        #expect(r.text == "")
        #expect(r.shouldSend)
    }
}
