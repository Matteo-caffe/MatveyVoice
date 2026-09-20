import Foundation

/// Что показывать в меню и иконке. Чистая логика без AppKit.
public enum MenuStatus: Equatable, Sendable {
    case ready
    case recording
    case processing
    case message(String)
    case noMicrophone
    case needAccessibility
    case modelMissing
    case modelDownloading(Double)
    case modelPreparing
    case modelFailed(String)

    /// Диктовка сейчас не сработает: есть что чинить.
    public var isProblem: Bool {
        switch self {
        case .noMicrophone, .needAccessibility, .modelMissing, .modelDownloading, .modelPreparing, .modelFailed: true
        default: false
        }
    }
}

public enum StatusLogic {
    public static func menuStatus(dictation: DictationState, permissions: PermissionsStatus,
                           hotkeyAvailable: Bool, model: ModelState) -> MenuStatus {
        switch dictation {
        case .recording: return .recording
        case .transcribing, .inserting: return .processing
        default: break
        }
        // Микрофон и Универсальный доступ: «не выдан» и «отозван» выглядят одинаково.
        if permissions.microphone != .granted { return .noMicrophone }
        if permissions.accessibility != .granted || !hotkeyAvailable { return .needAccessibility }
        switch model {
        case .notInstalled: return .modelMissing
        case .downloading(let progress): return .modelDownloading(progress)
        case .preparing: return .modelPreparing
        case .failed(let reason): return .modelFailed(reason)
        case .ready: break
        }
        if case .message(let text) = dictation { return .message(text) }
        return .ready
    }

    public static func permissionsGranted(_ p: PermissionsStatus) -> Bool {
        p.microphone == .granted && p.accessibility == .granted
    }

    public static func isSetupComplete(permissions: PermissionsStatus, model: ModelState) -> Bool {
        permissionsGranted(permissions) && model == .ready
    }

    /// Чек-лист при запуске: пока установка ни разу не была завершена, или если разрешения не выданы.
    public static func needsChecklist(setupCompleted: Bool, permissions: PermissionsStatus) -> Bool {
        !setupCompleted || !permissionsGranted(permissions)
    }

    public static func downloadedMegabytes(progress: Double, totalMegabytes: Int) -> Int {
        Int((min(max(progress, 0), 1) * Double(totalMegabytes)).rounded())
    }
}
