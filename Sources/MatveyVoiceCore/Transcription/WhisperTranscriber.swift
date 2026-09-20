import Foundation
import WhisperKit

/// `Transcribing` backed by WhisperKit. The only network use is the one-time model download
/// (and the tokenizer files WhisperKit fetches together with it). Audio and text are never
/// written to disk or logged.
public final class WhisperTranscriber: Transcribing, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: ModelState = .notInstalled
    private var _switchState: ModelState?
    private var pipeline: WhisperKit?
    private var loadedModelID: String?
    private var prepareTask: Task<Void, Never>?
    private var prepareGeneration = 0
    private let downloadBase: URL

    public init(downloadBase: URL? = nil) {
        self.downloadBase = downloadBase ?? Self.defaultDownloadBase
    }

    /// `~/Library/Application Support/MatveyVoice/Models`
    public static var defaultDownloadBase: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("MatveyVoice/Models", isDirectory: true)
    }

    public var state: ModelState {
        lock.withLock { _state }
    }

    /// Progress of loading a *different* model while the current one keeps working.
    /// nil when no switch is in progress (or after it succeeded / was cancelled); `.failed` if the
    /// new model could not be loaded. `state` stays `.ready` for the working model meanwhile.
    public var switchProgress: ModelState? {
        lock.withLock { _switchState }
    }

    private func setState(_ new: ModelState, generation: Int) {
        lock.withLock {
            guard generation == prepareGeneration else { return }
            if pipeline != nil { _switchState = new } else { _state = new }
        }
    }

    // MARK: prepare

    public func prepare(modelID: String) async {
        let task: Task<Void, Never>? = lock.withLock {
            if pipeline != nil, loadedModelID == modelID, case .ready = _state {
                prepareTask?.cancel()
                prepareGeneration += 1
                _switchState = nil
                return nil
            }
            prepareTask?.cancel()
            prepareGeneration += 1
            let generation = prepareGeneration
            let task = Task { [self] in await self.run(modelID: modelID, generation: generation) }
            prepareTask = task
            return task
        }
        await task?.value
    }

    public func cancelPrepare() {
        let task: Task<Void, Never>? = lock.withLock {
            let task = prepareTask
            prepareTask = nil
            prepareGeneration += 1
            // A previously loaded model (if any) stays usable; otherwise we are back to not installed.
            _state = pipeline != nil ? .ready : .notInstalled
            _switchState = nil
            return task
        }
        task?.cancel()
    }

    private func isCurrent(_ generation: Int) -> Bool {
        lock.withLock { generation == prepareGeneration }
    }

    private func install(_ kit: WhisperKit, modelID: String, generation: Int) {
        lock.withLock {
            guard generation == prepareGeneration else { return }
            pipeline = kit          // replaces the old model only now that the new one is ready
            loadedModelID = modelID
            _state = .ready
            _switchState = nil
        }
    }

    private func settleAfterCancel(generation: Int) {
        lock.withLock {
            guard generation == prepareGeneration else { return }
            _state = pipeline != nil ? .ready : .notInstalled
            _switchState = nil
        }
    }

    private func run(modelID: String, generation: Int) async {
        guard let variant = ModelCatalog.whisperKitVariant(for: modelID) else {
            setState(.failed(reason: TranscriptionErrorDescriber.string("error.unknownModel")), generation: generation)
            return
        }
        setState(.downloading(progress: 0), generation: generation)
        do {
            try FileManager.default.createDirectory(at: downloadBase, withIntermediateDirectories: true)
            let folder = try await WhisperKit.download(
                variant: variant,
                downloadBase: downloadBase,
                progressCallback: { [weak self] progress in
                    self?.setState(.downloading(progress: min(max(progress.fractionCompleted, 0), 1)), generation: generation)
                }
            )
            try Task.checkCancellation()
            setState(.preparing, generation: generation)
            let config = WhisperKitConfig(
                downloadBase: downloadBase,
                modelFolder: folder.path,
                tokenizerFolder: downloadBase,
                verbose: false,
                prewarm: true,
                load: true,
                download: false
            )
            let kit = try await WhisperKit(config)
            try Task.checkCancellation()
            install(kit, modelID: modelID, generation: generation)
        } catch {
            guard isCurrent(generation) else { return }
            if error is CancellationError {
                settleAfterCancel(generation: generation)
            } else {
                setState(.failed(reason: TranscriptionErrorDescriber.reason(for: error)), generation: generation)
            }
        }
    }

    // MARK: transcribe

    public func transcribe(_ audio: RecordedAudio, language: Language, hints: [String]) async throws -> Transcription? {
        guard !SpeechFilter.isSilent(audio.samples) else { return nil }
        let kit = lock.withLock { pipeline }
        guard let kit else { throw TranscriberError.notReady }

        // Auto mode is limited to ru/en: choose the likelier of the two.
        var code: String
        if language == .auto {
            let detected = try await kit.detectLangauge(audioArray: audio.samples)
            let ru = detected.langProbs["ru"] ?? -.infinity
            let en = detected.langProbs["en"] ?? -.infinity
            code = ru > en ? "ru" : "en"
        } else {
            code = language.rawValue
        }
        let promptTokens = Self.promptTokens(for: hints, tokenizer: kit.tokenizer)
        let results = try await kit.transcribe(
            audioArray: audio.samples,
            decodeOptions: Self.options(language: code, promptTokens: promptTokens)
        )
        let text = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !SpeechFilter.isHallucination(text) else { return nil }
        return Transcription(text: text, detectedLanguage: code)
    }

    private static func options(language: String, promptTokens: [Int]?) -> DecodingOptions {
        DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            promptTokens: promptTokens,
            noSpeechThreshold: 0.6
        )
    }

    /// Dictionary words as a decoder prompt (spelling hint). Empty dictionary gives no prompt.
    static func promptTokens(for hints: [String], tokenizer: WhisperTokenizer?) -> [Int]? {
        let words = hints.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !words.isEmpty, let tokenizer else { return nil }
        let tokens = tokenizer.encode(text: " " + words.joined(separator: ", "))
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        return tokens.isEmpty ? nil : tokens
    }
}
