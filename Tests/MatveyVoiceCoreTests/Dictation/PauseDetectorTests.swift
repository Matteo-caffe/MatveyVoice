import Testing
@testable import MatveyVoiceCore

@Suite struct PauseDetectorTests {
    private func audio(speech: Double, then quiet: Double, loud: Float = 0.2, floor: Float = 0.002) -> [Float] {
        let s = (0..<Int(speech * 16_000)).map { i in loud * (i % 2 == 0 ? 1 : -1) }
        let q = (0..<Int(quiet * 16_000)).map { i in floor * (i % 2 == 0 ? 1 : -1) }
        return s + q
    }

    @Test func speechFollowedByPauseIsDetected() {
        #expect(PauseDetector.endsWithPauseAfterSpeech(audio(speech: 1.5, then: 0.9)))
    }

    @Test func stillSpeakingOrPauseTooShortIsNot() {
        #expect(!PauseDetector.endsWithPauseAfterSpeech(audio(speech: 2, then: 0)))
        #expect(!PauseDetector.endsWithPauseAfterSpeech(audio(speech: 2, then: 0.4)))
    }

    @Test func silenceOrNoiseWithoutSpeechIsNot() {
        #expect(!PauseDetector.endsWithPauseAfterSpeech(audio(speech: 0, then: 3)))
        #expect(!PauseDetector.endsWithPauseAfterSpeech(audio(speech: 1, then: 1, loud: 0.004)))
        #expect(!PauseDetector.endsWithPauseAfterSpeech([]))
    }

    @Test func pauseIsRelativeToTheSpeechLevel() {
        // noisy room: the "quiet" part is loud in absolute terms but far below the speech
        #expect(PauseDetector.endsWithPauseAfterSpeech(audio(speech: 1, then: 1, loud: 0.3, floor: 0.02)))
        #expect(!PauseDetector.endsWithPauseAfterSpeech(audio(speech: 1, then: 1, loud: 0.05, floor: 0.02)))
    }
}
