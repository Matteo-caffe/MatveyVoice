import AppKit
import Observation
import ServiceManagement
import MatveyVoiceCore

/// Собирает настоящие модули воедино и держит наблюдаемое состояние для интерфейса.
@MainActor
@Observable
final class AppModel {
    @ObservationIgnored let settings = AppSettings()
    @ObservationIgnored let permissions = Permissions()
    @ObservationIgnored let transcriber = WhisperTranscriber()
    @ObservationIgnored let recorder = AudioRecorder()
    @ObservationIgnored let monitor = HotkeyMonitor()
    @ObservationIgnored let controller: DictationController
    @ObservationIgnored var overlay: OverlayController?
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var permissionsTask: Task<Void, Never>?
    @ObservationIgnored private var lastHotkey: Hotkey
    @ObservationIgnored private var lastAccessibilityAutoOpen: Date?
    @ObservationIgnored private var lastTapRetry = Date.distantPast
    @ObservationIgnored private var lastModelID: String

    var permissionsStatus: PermissionsStatus
    var modelState: ModelState = .notInstalled
    var switchProgress: ModelState?
    var hotkeyAvailable = false
    var launchAtLoginError: String?
    var setupCompleted: Bool {
        didSet { UserDefaults.standard.set(setupCompleted, forKey: "setupCompleted") }
    }

    init() {
        controller = DictationController(
            settings: settings, recorder: recorder, transcriber: transcriber, inserter: TextInserter(),
            postProcess: { TextPostProcessor.process($0, removeFillers: $1) }
        )
        permissionsStatus = permissions.status
        setupCompleted = UserDefaults.standard.bool(forKey: "setupCompleted")
        lastHotkey = settings.hotkey
        lastModelID = settings.modelID
    }

    var menuStatus: MenuStatus {
        StatusLogic.menuStatus(dictation: controller.state, permissions: permissionsStatus,
                               hotkeyAvailable: hotkeyAvailable, model: modelState)
    }

    // MARK: запуск

    func start() {
        overlay = OverlayController(controller: controller, recorder: recorder)
        syncLaunchAtLoginFromSystem()
        startPrepare()
        restartHotkey()

        permissionsTask = Task { [weak self, permissions] in
            for await status in permissions.changes {
                guard let self else { return }
                let accessibilityChanged = status.accessibility != self.permissionsStatus.accessibility
                self.permissionsStatus = status
                // Смена состояния микрофона не должна сбрасывать автомат клавиши.
                if accessibilityChanged { self.restartHotkey() }
            }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        observeSettings()
        trackChanges { [weak self] in
            guard let self else { return }
            if case .message(let text) = controller.state { messageShown(text) }
        }
    }

    /// После «Нужен доступ» ведём пользователя прямо в «Универсальный доступ», не чаще раза в 30 с.
    private func messageShown(_ text: String) {
        let needAccess = String(localized: "message.needAccess", table: "Dictation", bundle: .main)
        guard text == needAccess, permissionsStatus.accessibility != .granted else { return }
        let now = Date()
        if let last = lastAccessibilityAutoOpen, now.timeIntervalSince(last) < 30 { return }
        lastAccessibilityAutoOpen = now
        permissions.openSettings(.accessibility)
    }

    func stop() {
        tickTimer?.invalidate()
        permissionsTask?.cancel()
        monitor.stop()
        transcriber.cancelPrepare()
    }

    // MARK: модель

    func startPrepare() {
        let id = settings.modelID
        Task { [transcriber] in await transcriber.prepare(modelID: id) }
        tick()
    }

    private func tick() {
        if modelState != transcriber.state { modelState = transcriber.state }
        if switchProgress != transcriber.switchProgress { switchProgress = transcriber.switchProgress }
        if permissionsStatus.accessibility == .granted, !monitor.isAvailable {
            // Слежение могло не подняться сразу после выдачи доступа: пробуем не чаще раза в 5 с.
            if Date().timeIntervalSince(lastTapRetry) >= 5 {
                lastTapRetry = Date()
                restartHotkey()
            }
        } else if hotkeyAvailable != monitor.isAvailable {
            hotkeyAvailable = monitor.isAvailable
        }
        if StatusLogic.isSetupComplete(permissions: permissionsStatus, model: modelState), !setupCompleted {
            setupCompleted = true
        }
    }

    // MARK: клавиша

    func restartHotkey() {
        monitor.stop()
        lastTapRetry = Date()
        guard permissionsStatus.accessibility == .granted else {
            hotkeyAvailable = false
            return
        }
        monitor.start(
            hotkey: settings.hotkey,
            onPress: { [weak self] in MainActor.assumeIsolated { self?.hotkeyPressed() } },
            onRelease: { [weak self] in MainActor.assumeIsolated { self?.controller.handleRelease() } },
            onCancel: { [weak self] in MainActor.assumeIsolated { self?.controller.handleCancel() } }
        )
        hotkeyAvailable = monitor.isAvailable
    }

    private func hotkeyPressed() {
        // Проверка микрофона относится только к началу записи: второе нажатие в режиме
        // переключателя должно дойти до контроллера и остановить идущую запись.
        var starting = true
        if case .recording = controller.state { starting = false }
        if case .transcribing = controller.state { starting = false }
        if case .inserting = controller.state { starting = false }
        let mic = permissions.status.microphone
        if starting, mic != .granted {
            if mic == .notDetermined { Task { [permissions] in await permissions.request(.microphone) } }
            overlay?.flash(ui("overlay.noMicrophone"))
            return
        }
        controller.handlePress()
    }

    // MARK: настройки → поведение

    private func observeSettings() {
        trackChanges { [weak self] in
            guard let self else { return }
            let hotkey = settings.hotkey
            let modelID = settings.modelID
            let launch = settings.launchAtLogin
            if hotkey != lastHotkey {
                lastHotkey = hotkey
                restartHotkey()
            }
            if modelID != lastModelID {
                lastModelID = modelID
                startPrepare()
            }
            applyLaunchAtLogin(launch)
        }
    }

    private func syncLaunchAtLoginFromSystem() {
        let enabled = SMAppService.mainApp.status == .enabled
        if settings.launchAtLogin != enabled { settings.launchAtLogin = enabled }
    }

    private func applyLaunchAtLogin(_ wanted: Bool) {
        let service = SMAppService.mainApp
        let enabled = service.status == .enabled
        guard wanted != enabled else { return }
        do {
            if wanted { try service.register() } else { try service.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            let actual = service.status == .enabled
            if settings.launchAtLogin != actual { settings.launchAtLogin = actual }
        }
    }

    // MARK: действия меню

    func copyLastDictation() {
        guard let text = controller.lastResult else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }
}
