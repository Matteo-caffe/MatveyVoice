import AppKit
import SwiftUI
import MatveyVoiceCore

/// Панель, которая не забирает фокус: активное приложение и поле ввода остаются прежними.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    /// Записи короче этого порога плашку не показывают (контроллер их всё равно отбрасывает).
    static let recordingDelay: Duration = .seconds(DictationController.minimumRecordingDuration)

    private let controller: DictationController
    private let model = OverlayModel()
    private let panel: NSPanel
    private var showTask: Task<Void, Never>?
    private var appearTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?
    private var flashing = false

    init(controller: DictationController, recorder: any AudioRecording) {
        self.controller = controller
        let size = OverlayMetrics.panelSize
        let panel = NonActivatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Тень рисует сама плашка: у прозрачного окна системная осталась бы прямоугольной.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: OverlayView(model: model))
        host.frame = NSRect(origin: .zero, size: size)
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
            model.wave.reset()
            model.recordingStart = Date()
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
        hideTask?.cancel()
        appearTask?.cancel()
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 4))
        if panel.isVisible {
            model.isShown = true
            return
        }
        // Сначала окно с невидимой плашкой, и только потом «вырастание»: иначе анимации не будет.
        model.isShown = false
        panel.orderFrontRegardless()
        appearTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            self?.model.isShown = true
        }
    }

    private func dismiss() {
        appearTask?.cancel()
        guard panel.isVisible else { return }
        model.isShown = false
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self, !self.model.isShown else { return }
            self.panel.orderOut(nil)
        }
    }
}
