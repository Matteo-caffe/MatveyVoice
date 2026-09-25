import Foundation

public protocol AudioRecording: AnyObject, Sendable {
    func start() throws
    func stop() -> RecordedAudio
    var levels: AsyncStream<Float> { get }
}

public protocol Transcribing: AnyObject, Sendable {
    var state: ModelState { get }
    func prepare(modelID: String) async
    /// Returns nil when there is no speech.
    func transcribe(_ audio: RecordedAudio, language: Language, hints: [String]) async throws -> Transcription?
    func cancelPrepare()
}

public protocol TextInserting: AnyObject, Sendable {
    /// - Parameters:
    ///   - pressReturn: после вставки синтетически нажать Return (голосовая отправка).
    ///   - commandReturn: нажать с ⌘ — для приложений вроде Telegram с настройкой «Отправлять по ⌘+Return».
    func insert(_ text: String, pressReturn: Bool, commandReturn: Bool) async throws -> InsertResult
}

public extension TextInserting {
    func insert(_ text: String) async throws -> InsertResult {
        try await insert(text, pressReturn: false, commandReturn: false)
    }
    func insert(_ text: String, pressReturn: Bool) async throws -> InsertResult {
        try await insert(text, pressReturn: pressReturn, commandReturn: false)
    }
}

public protocol PermissionsProviding: AnyObject, Sendable {
    var status: PermissionsStatus { get }
    func request(_ kind: PermissionKind) async
    func openSettings(_ kind: PermissionKind)
    var changes: AsyncStream<PermissionsStatus> { get }
}
