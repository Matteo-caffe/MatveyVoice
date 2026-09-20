import Foundation
import MatveyVoiceCore

/// Что показывать в меню и иконке. Чистая логика без AppKit.
enum MenuStatus: Equatable {
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
    var isProblem: Bool {
        switch self {
        case .noMicrophone, .needAccessibility, .modelMissing, .modelDownloading, .modelPreparing, .modelFailed: true
        default: false
        }
    }
}

enum StatusLogic {
    static func menuStatus(dictation: DictationState, permissions: PermissionsStatus,
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

    static func permissionsGranted(_ p: PermissionsStatus) -> Bool {
        p.microphone == .granted && p.accessibility == .granted
    }

    static func isSetupComplete(permissions: PermissionsStatus, model: ModelState) -> Bool {
        permissionsGranted(permissions) && model == .ready
    }

    /// Чек-лист при запуске: пока установка ни разу не была завершена, или если разрешения не выданы.
    static func needsChecklist(setupCompleted: Bool, permissions: PermissionsStatus) -> Bool {
        !setupCompleted || !permissionsGranted(permissions)
    }

    static func downloadedMegabytes(progress: Double, totalMegabytes: Int) -> Int {
        Int((min(max(progress, 0), 1) * Double(totalMegabytes)).rounded())
    }
}
