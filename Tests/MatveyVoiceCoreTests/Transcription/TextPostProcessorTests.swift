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
}
