import Foundation
import AVFoundation
import ApplicationServices
import AppKit

/// Microphone + Accessibility. Accessibility covers both the key tap (active CGEventTap)
/// and the synthetic Cmd+V, so Input Monitoring is deliberately not requested.
public final class Permissions: PermissionsProviding, @unchecked Sendable {
    public init() {}

    public var status: PermissionsStatus {
        PermissionsStatus(microphone: Self.microphoneState(), accessibility: Self.accessibilityState())
    }

    public func request(_ kind: PermissionKind) async {
        switch kind {
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .accessibility:
            // Shows the system prompt and registers the app in the Accessibility list.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    public func openSettings(_ kind: PermissionKind) {
        let anchor = kind == .microphone ? "Privacy_Microphone" : "Privacy_Accessibility"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Emits the current status immediately and again whenever it changes (polled once a second).
    public var changes: AsyncStream<PermissionsStatus> {
        AsyncStream { continuation in
            let task = Task { [self] in
                var last: PermissionsStatus?
                while !Task.isCancelled {
                    let now = status
                    if now != last { last = now; continuation.yield(now) }
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    static func accessibilityState() -> PermissionState {
        // The API cannot tell "never asked" from "denied"; treat untrusted as notDetermined.
        AXIsProcessTrusted() ? .granted : .notDetermined
    }
}
