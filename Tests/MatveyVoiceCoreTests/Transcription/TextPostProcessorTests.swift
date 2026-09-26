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
        let text = "Это эмоции, umbrella и uhura, эхо"
        #expect(TextPostProcessor.process(text, removeFillers: true) == text)
    }

    @Test func cleansCommasAroundRemovedFiller() {
        #expect(TextPostProcessor.process("Ну, э, я думаю", removeFillers: true) == "Я думаю")
        #expect(TextPostProcessor.process("Я думаю, эм.", removeFillers: true) == "Я думаю.")
        #expect(TextPostProcessor.process("Well, um, yes", removeFillers: true) == "Yes")
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

    // MARK: слова-паразиты и вода

    private func clean(_ text: String) -> String { TextPostProcessor.process(text, removeFillers: true) }

    @Test func fillerSetOffByCommasIsRemovedAnywhere() {
        #expect(clean("Ну, я думаю, что это работает.") == "Я думаю, что это работает.")
        #expect(clean("Короче, надо переделать интерфейс.") == "Надо переделать интерфейс.")
        #expect(clean("Я пришёл, типа, а там никого.") == "Я пришёл, а там никого.")
        #expect(clean("Это, как бы, не совсем то.") == "Это не совсем то.")
        #expect(clean("Мы всё сделали, в общем.") == "Мы всё сделали.")
        #expect(clean("Интерфейс перегружен, вот.") == "Интерфейс перегружен.")
        #expect(clean("Ну, короче, в общем, завтра созвонимся.") == "Завтра созвонимся.")
        #expect(clean("It is, like, really slow, you know.") == "It is really slow.")
        #expect(clean("Well, I mean, it works.") == "It works.")
    }

    @Test func typicalLeadingFillerIsRemovedWithoutComma() {
        #expect(clean("Ну я думаю, что да.") == "Я думаю, что да.")
        #expect(clean("Короче я сегодня допишу.") == "Я сегодня допишу.")
        #expect(clean("Привет. Так вот я про проект.") == "Привет. Я про проект.")
        #expect(clean("Вот так вот сегодня такие изменения.") == "Сегодня такие изменения.")
    }

    @Test func sentencesOfPureFillerAreDropped() {
        #expect(clean("Тестировал в заметках. Вот так вот. Сегодня такие изменения.") == "Тестировал в заметках. Сегодня такие изменения.")
        #expect(clean("Всё готово. Ну вот. Как-то так.") == "Всё готово.")
        #expect(clean("Работает! Такие дела") == "Работает!")
        #expect(clean("Сделал. Ну типа того.") == "Сделал.")
        #expect(clean("Вот так вот.") == "")
    }

    @Test func meaningfulUsesAreKept() {
        for text in ["Вот почему я пришёл.", "Вот он, этот файл.", "Это значит, что всё работает.",
                     "Сделай текст короче.", "В общем чате написали.", "Как бы не опоздать.",
                     "Нужен другой тип данных.", "Ну и что?", "So what do we do?", "I like it.",
                     "Я сделал это так, как ты сказал."] {
            #expect(clean(text) == text)
        }
    }

    @Test func stutteredWordsAndPhrasesAreCollapsed() {
        #expect(clean("Я я думаю, что это что это работает.") == "Я думаю, что это работает.")
        #expect(clean("Мы мы пойдём, мы пойдём завтра.") == "Мы пойдём завтра.")
        #expect(clean("It is is fine.") == "It is fine.")
    }

    @Test func intentionalRepetitionsAreKept() {
        for text in ["Да да, конечно.", "Нет нет, не так.", "Очень очень быстро.", "Hey hey, look."] {
            #expect(clean(text) == text)
        }
    }

    @Test func userDictationLosesOnlyTheWater() {
        let text = "Взял что-то из Aqua Voice, то есть проверял в заметках, тестировал. Также использовал терминал. Вот так вот. Сегодня такие изменения."
        #expect(clean(text) == "Взял что-то из Aqua Voice, то есть проверял в заметках, тестировал. Также использовал терминал. Сегодня такие изменения.")
    }

    @Test func extractSendCommandStripsTrailingKeywordAndKeepsSentencePunctuation() {
        let r = TextPostProcessor.extractSendCommand("Привет, как дела? Отправить", keyword: "отправить")
        #expect(r.text == "Привет, как дела?")
        #expect(r.shouldSend)
    }

    @Test(arguments: ["Привет, отправить.", "Привет; отправить", "Привет: отправить", "Привет — отправить", "Привет - отправить"])
    func extractSendCommandDropsDanglingPunctuationBeforeKeyword(text: String) {
        let r = TextPostProcessor.extractSendCommand(text, keyword: "отправить")
        #expect(r.text == "Привет")
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
