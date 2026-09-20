import Foundation
import Observation

/// Сценарий диктовки: нажал → записал → распознал → вставил.
/// Работает только через протоколы; текст диктовки не логируется и на диск не пишется.
@MainActor
@Observable
public final class DictationController {
    public private(set) var state: DictationState = .idle
    /// Последний результат, только в памяти.
    public private(set) var lastResult: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let recorder: any AudioRecording
    @ObservationIgnored private let transcriber: any Transcribing
    @ObservationIgnored private let inserter: any TextInserting
    @ObservationIgnored private let postProcess: @Sendable (String, Bool) -> String
    @ObservationIgnored private let sleep: @Sendable (TimeInterval) async -> Void
    @ObservationIgnored private let minimumDuration: TimeInterval
    @ObservationIgnored private let maximumDuration: TimeInterval
    @ObservationIgnored private let messageDuration: TimeInterval

    @ObservationIgnored private var limitTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var isProcessing = false
    @ObservationIgnored private var pipelineTask: Task<Void, Never>?

    /// - Parameters:
    ///   - postProcess: постобработка текста (`TextPostProcessor.process`), по умолчанию тождественная.
    ///   - sleep: подставляемые часы (секунды); тесты не ждут по-настоящему.
    public init(
        settings: AppSettings,
        recorder: any AudioRecording,
        transcriber: any Transcribing,
        inserter: any TextInserting,
        postProcess: @escaping @Sendable (String, Bool) -> String = { text, _ in text },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        minimumDuration: TimeInterval = 0.3,
        maximumDuration: TimeInterval = 300,
        messageDuration: TimeInterval = 3
    ) {
        self.settings = settings
        self.recorder = recorder
        self.transcriber = transcriber
        self.inserter = inserter
        self.postProcess = postProcess
        self.sleep = sleep
        self.minimumDuration = minimumDuration
        self.maximumDuration = maximumDuration
        self.messageDuration = messageDuration
    }

    public func handlePress() {
        switch state {
        case .recording:
            if settings.triggerMode == .toggle { finishRecording() }
        case .transcribing, .inserting:
            return
        case .idle, .message:
            if !isProcessing { beginRecording() }
        }
    }

    public func handleRelease() {
        guard settings.triggerMode == .hold, state == .recording else { return }
        finishRecording()
    }

    public func handleCancel() {
        guard state == .recording else { return }
        limitTask?.cancel()
        _ = recorder.stop()
        state = .idle
    }

    /// Ждёт конца текущего распознавания и вставки (для тестов и завершения приложения).
    public func waitForCompletion() async {
        await pipelineTask?.value
    }

    // MARK: - Внутреннее

    private func beginRecording() {
        messageTask?.cancel()
        switch transcriber.state {
        case .ready:
            break
        case .notInstalled:
            return show(String(localized: "message.modelNotInstalled", table: "Dictation", bundle: .main))
        case .downloading:
            return show(String(localized: "message.modelDownloading", table: "Dictation", bundle: .main))
        case .preparing:
            return show(String(localized: "message.modelPreparing", table: "Dictation", bundle: .main))
        case .failed(let reason):
            return show(String(localized: "message.modelFailed \(reason)", table: "Dictation", bundle: .main))
        }
        do {
            try recorder.start()
        } catch {
            return show(String(localized: "message.recordFailed \(error.localizedDescription)", table: "Dictation", bundle: .main))
        }
        state = .recording
        let limit = maximumDuration
        let sleep = self.sleep
        limitTask = Task { [weak self] in
            await sleep(limit)
            guard !Task.isCancelled else { return }
            self?.finishRecording(hitLimit: true)
        }
    }

    private func finishRecording(hitLimit: Bool = false) {
        guard state == .recording else { return }
        limitTask?.cancel()
        let audio = recorder.stop()
        guard audio.duration >= minimumDuration else {
            state = .idle
            return
        }
        // При лимите пользователь видит сообщение, пока идёт распознавание; итог его заменит.
        state = hitLimit ? .message(text: String(localized: "message.recordingLimit", table: "Dictation", bundle: .main)) : .transcribing
        isProcessing = true
        let language = settings.language
        let hints = settings.dictionary
        let removeFillers = settings.removeFillers
        pipelineTask = Task { [weak self] in
            await self?.process(audio, language: language, hints: hints, removeFillers: removeFillers)
        }
    }

    private func process(_ audio: RecordedAudio, language: Language, hints: [String], removeFillers: Bool) async {
        defer { isProcessing = false }
        let result: Transcription?
        do {
            result = try await transcriber.transcribe(audio, language: language, hints: hints)
        } catch {
            return show(String(localized: "message.recognitionFailed \(error.localizedDescription)", table: "Dictation", bundle: .main))
        }
        guard let result else { return showNoSpeech() }
        let text = postProcess(result.text, removeFillers)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return showNoSpeech() }
        lastResult = text
        state = .inserting
        do {
            switch try await inserter.insert(text) {
            case .inserted:
                state = .idle
            case .copiedOnly:
                show(String(localized: "message.needAccess", table: "Dictation", bundle: .main))
            }
        } catch {
            show(String(localized: "message.insertFailed \(error.localizedDescription)", table: "Dictation", bundle: .main))
        }
    }

    private func showNoSpeech() {
        show(String(localized: "message.noSpeech", table: "Dictation", bundle: .main))
    }

    private func show(_ text: String) {
        state = .message(text: text)
        messageTask?.cancel()
        let duration = messageDuration
        let sleep = self.sleep
        messageTask = Task { [weak self] in
            await sleep(duration)
            guard !Task.isCancelled, let self else { return }
            if case .message = self.state { self.state = .idle }
        }
    }

}
