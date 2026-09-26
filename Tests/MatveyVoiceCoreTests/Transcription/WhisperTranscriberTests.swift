import Testing
@testable import MatveyVoiceCore

@Suite struct WhisperTranscriberTests {
    @Test func promptIsThePunctuationSampleInTheSpeechLanguage() {
        #expect(WhisperTranscriber.promptText(for: [], language: "ru") == WhisperTranscriber.punctuationSamples["ru"])
        #expect(WhisperTranscriber.promptText(for: [], language: "en") == WhisperTranscriber.punctuationSamples["en"])
    }

    @Test func dictionaryFollowsTheSampleAsAFinishedSentence() {
        let text = WhisperTranscriber.promptText(for: [" Aqua Voice", "", "GitHub ", "Claude Code"], language: "ru")
        #expect(text == WhisperTranscriber.punctuationSamples["ru"]! + " Aqua Voice, GitHub, Claude Code.")
    }

    @Test func unknownLanguageKeepsOnlyTheDictionary() {
        #expect(WhisperTranscriber.promptText(for: ["Anna"], language: "de") == "Anna.")
        #expect(WhisperTranscriber.promptText(for: [], language: "de") == "")
    }
}

@Suite struct WhisperFallbackTests {
    @Test func confidentOrEmptyGreedyResultIsKept() {
        #expect(!WhisperTranscriber.needsFallback([]))
        #expect(!WhisperTranscriber.needsFallback([(compressionRatio: 0, avgLogprob: 0)]))       // noise: nothing heard
        #expect(!WhisperTranscriber.needsFallback([(compressionRatio: 1.2, avgLogprob: -0.1)]))  // normal speech
    }

    @Test func loopOrLowConfidenceRetriesWithFallback() {
        #expect(WhisperTranscriber.needsFallback([(compressionRatio: 3.1, avgLogprob: -0.1)]))
        #expect(WhisperTranscriber.needsFallback([(compressionRatio: 1.1, avgLogprob: -0.1), (compressionRatio: 1.0, avgLogprob: -1.4)]))
    }
}
