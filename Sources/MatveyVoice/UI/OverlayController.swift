import AppKit
import SwiftUI
import Observation
import MatveyVoiceCore

@MainActor
@Observable
final class OverlayModel {
    enum Content: Equatable { case recording, transcribing, text(String) }
    var content: Content = .transcribing
    var level: Float = 0
}

/// Панель, которая не забирает фокус: активное приложение и поле ввода остаются прежними.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    /// Записи короче этого порога плашку не показывают (контроллер их всё равно отбрасывает).
    static let recordingDelay: Duration = .milliseconds(300)

    private let controller: DictationController
    private let model = OverlayModel()
    private let panel: NSPanel
    private var showTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?
    private var flashing = false

    init(controller: DictationController, recorder: any AudioRecording) {
        self.controller = controller
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 56),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: OverlayView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 56)
        panel.contentView = host
        self.panel = panel

        let levels = recorder.levels
        levelsTask = Task { [weak self] in
            for await level in levels { self?.model.level = level }
        }
        trackChanges { [weak self] in self?.stateChanged() }
    }

    /// Короткое сообщение от самого интерфейса (например, нет доступа к микрофону).
    func flash(_ text: String, seconds: Double = 3) {
        flashTask?.cancel()
        flashing = true
        model.content = .text(text)
        present()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.flashing = false
            self.stateChanged(force: true)
        }
    }

    private func stateChanged(force: Bool = false) {
        let state = controller.state
        if flashing, !force, state == .idle { return }
        if state != .idle { flashTask?.cancel(); flashing = false }
        showTask?.cancel()
        switch state {
        case .idle:
            dismiss()
        case .recording:
            model.level = 0
            // Плашка записи появляется с задержкой: короткое нажатие не мигает.
            showTask = Task { [weak self] in
                try? await Task.sleep(for: Self.recordingDelay)
                guard !Task.isCancelled, let self, self.controller.state == .recording else { return }
                self.model.content = .recording
                self.present()
            }
        case .transcribing, .inserting:
            model.content = .transcribing
            present()
        case .message(let text):
            // Как и .transcribing: после лимита записи здесь идёт распознавание, итог заменит текст.
            model.content = .text(text)
            present()
        }
    }

    private func present() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 28))
        panel.orderFrontRegardless()
    }

    private func dismiss() {
        panel.orderOut(nil)
    }
}

private struct OverlayView: View {
    let model: OverlayModel

    var body: some View {
        HStack(spacing: 10) {
            switch model.content {
            case .recording:
                Image(systemName: "mic.fill").foregroundStyle(.red)
                LevelBars(level: model.level)
                    .accessibilityLabel(ui("a11y.overlay.level"))
                Text(ui("overlay.recording"))
            case .transcribing:
                ProgressView().controlSize(.small)
                Text(ui("overlay.transcribing"))
            case .text(let text):
                Text(text).lineLimit(2).multilineTextAlignment(.center)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 16)
        .frame(width: 300, height: 56)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LevelBars: View {
    let level: Float
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                let threshold = Float(index) / 7
                Capsule()
                    .fill(level > threshold ? Color.red : Color.secondary.opacity(0.35))
                    .frame(width: 4, height: 6 + CGFloat(index) * 2.5)
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
