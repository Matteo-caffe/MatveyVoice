import Testing
import Foundation
@testable import MatveyVoiceCore

private final class FakeRecorder: AudioRecording, @unchecked Sendable {
    var duration: TimeInterval = 2
    var startCalls = 0, stopCalls = 0
    var startError: Error?
    var levels: AsyncStream<Float> { AsyncStream { $0.finish() } }
    func start() throws { if let startError { throw startError }; startCalls += 1 }
    func stop() -> RecordedAudio { stopCalls += 1; return RecordedAudio(samples: [0.1], duration: duration) }
}

private struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }

private final class FakeTranscriber: Transcribing, @unchecked Sendable {
    var state: ModelState = .ready
    var result: Transcription? = Transcription(text: "привет мир")
    var error: Error?
    var calls: [(Language, [String])] = []
    var gate: CheckedContinuation<Void, Never>?
    var blocking = false
    func prepare(modelID: String) async {}
    func cancelPrepare() {}
    func transcribe(_ audio: RecordedAudio, language: Language, hints: [String]) async throws -> Transcription? {
        calls.append((language, hints))
        if blocking { await withCheckedContinuation { gate = $0 } }
        if let error { throw error }
        return result
    }
    func release() { gate?.resume(); gate = nil }
}

private final class FakeInserter: TextInserting, @unchecked Sendable {
    var inserted: [String] = []
    var pressedReturn: [Bool] = []
    var pressedCommandReturn: [Bool] = []
    var result: InsertResult = .inserted
    var error: Error?
    func insert(_ text: String, pressReturn: Bool, commandReturn: Bool) async throws -> InsertResult {
        inserted.append(text)
        pressedReturn.append(pressReturn)
        pressedCommandReturn.append(commandReturn)
        if let error { throw error }
        return result
    }
}

/// Ручные часы: sleep висит, пока тест не вызовет fire.
private final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [(TimeInterval, CheckedContinuation<Void, Never>)] = []
    func sleep(_ s: TimeInterval) async {
        await withCheckedContinuation { c in lock.withLock { waiters.append((s, c)) } }
    }
    func waiting(_ s: TimeInterval) -> Bool { lock.withLock { waiters.contains { $0.0 == s } } }
    func fire(_ s: TimeInterval) {
        let ready = lock.withLock {
            let r = waiters.filter { $0.0 == s }; waiters.removeAll { $0.0 == s }; return r
        }
        ready.forEach { $0.1.resume() }
    }
}

@MainActor
private struct Rig {
    let settings: AppSettings
    let recorder = FakeRecorder()
    let transcriber = FakeTranscriber()
    let inserter = FakeInserter()
    let clock = ManualClock()
    let controller: DictationController

    init(mode: TriggerMode = .hold, post: @escaping @Sendable (String, Bool) -> String = { t, _ in t }) {
        let defaults = UserDefaults(suiteName: "dc-\(UUID().uuidString)")!
        settings = AppSettings(defaults: defaults)
        settings.triggerMode = mode
        let clock = self.clock
        controller = DictationController(settings: settings, recorder: recorder, transcriber: transcriber,
                                         inserter: inserter, postProcess: post,
                                         sleep: { await clock.sleep($0) })
    }

    func waitUntil(_ cond: () -> Bool) async {
        for _ in 0..<1000 where !cond() { await Task.yield() }
    }
}

// Вне приложения таблица Dictation недоступна, и String(localized:) возвращает ключ (с подставленным аргументом).
@MainActor
@Suite struct DictationControllerTests {
    @Test func fullPathInsertsTextAndReturnsToIdle() async {
        let r = Rig()
        r.settings.language = .ru
        r.settings.dictionary = ["Matvey"]
        r.controller.handlePress()
        #expect(r.controller.state == .recording)
        r.controller.handleRelease()
        #expect(r.controller.state == .transcribing)
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет мир"])
        #expect(r.controller.state == .idle)
        #expect(r.controller.lastResult == "привет мир")
        #expect(r.transcriber.calls.first?.0 == .ru)
        #expect(r.transcriber.calls.first?.1 == ["Matvey"])
    }

    @Test(arguments: [true, false]) func postProcessorReceivesRemoveFillersFromSettings(flag: Bool) async {
        let r = Rig(post: { text, fillers in fillers ? text.uppercased() : text })
        r.settings.removeFillers = flag
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == [flag ? "ПРИВЕТ МИР" : "привет мир"])
    }

    @Test func emptyTextAfterPostProcessingIsSilence() async {
        let r = Rig(post: { _, _ in "  " })
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.noSpeech"))
        #expect(r.inserter.inserted.isEmpty)
    }

    @Test func withoutSendKeywordConfiguredReturnIsNeverPressed() async {
        let r = Rig()
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет мир"])
        #expect(r.inserter.pressedReturn == [false])
    }

    @Test func trailingSendKeywordIsStrippedAndTriggersReturn() async {
        let r = Rig()
        r.settings.sendKeyword = "отправить"
        r.transcriber.result = Transcription(text: "привет, как дела? отправить")
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет, как дела?"])
        #expect(r.inserter.pressedReturn == [true])
        #expect(r.controller.lastResult == "привет, как дела?")
        #expect(r.controller.state == .idle)
    }

    @Test func sendKeywordAloneWithNoOtherSpeechIsTreatedAsSilence() async {
        let r = Rig()
        r.settings.sendKeyword = "отправить"
        r.transcriber.result = Transcription(text: "отправить")
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.noSpeech"))
        #expect(r.inserter.inserted.isEmpty)
    }

    @Test func sendUsesCommandReturnSettingIsPassedToInserter() async {
        let r = Rig()
        r.settings.sendKeyword = "отправить"
        r.settings.sendUsesCommandReturn = true
        r.transcriber.result = Transcription(text: "привет отправить")
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.inserter.pressedReturn == [true])
        #expect(r.inserter.pressedCommandReturn == [true])
    }

    @Test func cancelDiscardsRecordingWithoutTrace() async {
        let r = Rig()
        r.controller.handlePress()
        r.controller.handleCancel()
        #expect(r.controller.state == .idle)
        #expect(r.recorder.stopCalls == 1)
        await r.controller.waitForCompletion()
        #expect(r.transcriber.calls.isEmpty)
        #expect(r.inserter.inserted.isEmpty)
        #expect(r.controller.lastResult == nil)
    }

    @Test func shortPressIsDroppedSilentlyAndMicClosed() {
        let r = Rig()
        r.recorder.duration = 0.29
        r.controller.handlePress(); r.controller.handleRelease()
        #expect(r.controller.state == .idle)
        #expect(r.recorder.stopCalls == 1)
        #expect(r.transcriber.calls.isEmpty)
    }

    @Test func pressOfExactlyThresholdIsTranscribed() async {
        let r = Rig()
        r.recorder.duration = 0.3
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет мир"])
    }

    @Test func silenceShowsMessageAndInsertsNothing() async {
        let r = Rig()
        r.transcriber.result = nil
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.noSpeech"))
        #expect(r.inserter.inserted.isEmpty)
        #expect(r.controller.lastResult == nil)
    }

    @Test func messageReturnsToIdleAfterDelay() async {
        let r = Rig()
        r.transcriber.result = nil
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        await r.waitUntil { r.clock.waiting(3) }
        r.clock.fire(3)
        await r.waitUntil { r.controller.state == .idle }
        #expect(r.controller.state == .idle)
    }

    @Test func staleMessageTimerDoesNotResetNewRecording() async {
        let r = Rig()
        r.transcriber.result = nil
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        await r.waitUntil { r.clock.waiting(3) }
        r.controller.handlePress()
        #expect(r.controller.state == .recording)
        r.clock.fire(3)
        for _ in 0..<50 { await Task.yield() }
        #expect(r.controller.state == .recording)
    }

    @Test func recognitionErrorShowsReasonAndRecovers() async {
        let r = Rig()
        r.transcriber.error = Boom()
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.recognitionFailed boom"))
        r.transcriber.error = nil
        r.controller.handlePress()
        #expect(r.controller.state == .recording)
    }

    @Test func pressWhileTranscribingIsIgnored() async {
        let r = Rig()
        r.transcriber.blocking = true
        r.controller.handlePress(); r.controller.handleRelease()
        await r.waitUntil { r.transcriber.gate != nil }
        r.controller.handlePress(); r.controller.handleRelease(); r.controller.handleCancel()
        #expect(r.controller.state == .transcribing)
        #expect(r.recorder.startCalls == 1)
        r.transcriber.release()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет мир"])
        #expect(r.controller.state == .idle)
    }

    @Test func toggleModeStartsAndStopsOnPresses() async {
        let r = Rig(mode: .toggle)
        r.controller.handlePress()
        r.controller.handleRelease()
        #expect(r.controller.state == .recording)
        r.controller.handlePress()
        #expect(r.controller.state == .transcribing)
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted.count == 1)
    }

    @Test func holdModeIgnoresSecondPressWhileRecording() {
        let r = Rig()
        r.controller.handlePress(); r.controller.handlePress()
        #expect(r.controller.state == .recording)
        #expect(r.recorder.startCalls == 1)
    }

    @Test func recordingHittingLimitShowsMessageAndIsStillTranscribed() async {
        let r = Rig()
        r.transcriber.blocking = true
        r.controller.handlePress()
        await r.waitUntil { r.clock.waiting(300) }
        r.clock.fire(300)
        await r.waitUntil { r.transcriber.gate != nil }
        #expect(r.controller.state == .message(text: "message.recordingLimit"))
        r.controller.handlePress()
        #expect(r.recorder.startCalls == 1)
        r.transcriber.release()
        await r.controller.waitForCompletion()
        #expect(r.inserter.inserted == ["привет мир"])
        #expect(r.controller.state == .idle)
    }

    @Test(arguments: [
        (ModelState.notInstalled, "message.modelNotInstalled"),
        (ModelState.downloading(progress: 0.4), "message.modelDownloading"),
        (ModelState.preparing, "message.modelPreparing"),
        (ModelState.failed(reason: "disk"), "message.modelFailed disk"),
    ]) func modelNotReadyBlocksRecordingWithReason(model: ModelState, expected: String) {
        let r = Rig()
        r.transcriber.state = model
        r.controller.handlePress()
        #expect(r.controller.state == .message(text: expected))
        #expect(r.recorder.startCalls == 0)
    }

    @Test func recorderStartFailureShowsMessage() {
        let r = Rig()
        r.recorder.startError = Boom()
        r.controller.handlePress()
        #expect(r.controller.state == .message(text: "message.recordFailed boom"))
    }

    @Test func copiedOnlyShowsAccessMessageButKeepsLastResult() async {
        let r = Rig()
        r.inserter.result = .copiedOnly(reason: "no access")
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.needAccess"))
        #expect(r.controller.lastResult == "привет мир")
    }

    @Test func blockedSecureFieldShowsMessage() async {
        let r = Rig()
        r.inserter.result = .blockedSecureField
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.secureField"))
    }

    @Test func insertThrowingShowsMessage() async {
        let r = Rig()
        r.inserter.error = Boom()
        r.controller.handlePress(); r.controller.handleRelease()
        await r.controller.waitForCompletion()
        #expect(r.controller.state == .message(text: "message.insertFailed boom"))
    }
}
