import AppKit
import SwiftUI
import MatveyVoiceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var menu: StatusMenuController?
    private var settingsWindow: WindowPresenter?
    private var checklistWindow: WindowPresenter?

    /// Две копии, запущенные одновременно, не должны погасить друг друга: уступает более поздняя
    /// (по времени запуска, при равенстве — по pid).
    static func shouldYieldToOtherInstance() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let me = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { other in
            guard other.processIdentifier != me.processIdentifier else { return false }
            switch (other.launchDate, me.launchDate) {
            case let (o?, m?) where o != m: return o < m
            default: return other.processIdentifier < me.processIdentifier
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model

        settingsWindow = WindowPresenter(title: ui("settings.title")) { _ in
            NSHostingView(rootView: SettingsView(settings: model.settings, model: model))
        }
        checklistWindow = WindowPresenter(title: ui("checklist.window")) { close in
            NSHostingView(rootView: ChecklistView(model: model, close: close))
        }
        menu = StatusMenuController(
            model: model,
            openSettings: { [weak self] in self?.settingsWindow?.show() },
            openChecklist: { [weak self] in self?.checklistWindow?.show() }
        )
        model.start()

        if StatusLogic.needsChecklist(setupCompleted: model.setupCompleted, permissions: model.permissionsStatus) {
            checklistWindow?.show()
            if model.permissionsStatus.microphone == .notDetermined {
                Task { await model.permissions.request(.microphone) }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}
