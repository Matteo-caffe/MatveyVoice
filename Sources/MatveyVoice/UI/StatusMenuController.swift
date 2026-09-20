import AppKit
import MatveyVoiceCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let openSettings: () -> Void
    private let openChecklist: () -> Void

    init(model: AppModel, openSettings: @escaping () -> Void, openChecklist: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        self.openChecklist = openChecklist
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        trackChanges { [weak self] in self?.updateIcon() }
    }

    private func updateIcon() {
        let status = model.menuStatus
        let (symbol, description): (String, String) = switch status {
        case .recording: ("mic.fill", "a11y.statusItem.recording")
        case .processing: ("waveform", "a11y.statusItem.processing")
        case .noMicrophone: ("mic.slash", "a11y.statusItem.warning")
        case .needAccessibility, .modelFailed: ("exclamationmark.triangle", "a11y.statusItem.warning")
        case .modelMissing, .modelDownloading, .modelPreparing: ("arrow.down.circle", "a11y.statusItem.model")
        case .ready, .message: ("mic", "a11y.statusItem")
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: ui(description))
        statusItem.button?.setAccessibilityLabel(ui(description))
    }

    static func title(for status: MenuStatus) -> String {
        switch status {
        case .ready: ui("menu.status.ready")
        case .recording: ui("menu.status.recording")
        case .processing: ui("menu.status.processing")
        case .message(let text): text
        case .noMicrophone: ui("menu.status.noMicrophone")
        case .needAccessibility: ui("menu.status.needAccessibility")
        case .modelMissing: ui("menu.status.modelMissing")
        case .modelDownloading(let p): ui("menu.status.modelDownloading", Int((p * 100).rounded()))
        case .modelPreparing: ui("menu.status.modelPreparing")
        case .modelFailed(let reason): ui("menu.status.modelFailed", reason)
        }
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = model.menuStatus
        let statusLine = NSMenuItem(title: Self.title(for: status), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        statusLine.image = Self.dot(for: status)
        menu.addItem(statusLine)

        switch status {
        case .noMicrophone:
            menu.addItem(item("menu.openMicrophoneSettings", #selector(openMicrophonePrivacy), symbol: "mic.slash"))
        case .needAccessibility:
            menu.addItem(item("menu.openAccessibilitySettings", #selector(openAccessibilityPrivacy), symbol: "hand.raised"))
        default: break
        }
        if status.isProblem { menu.addItem(item("menu.setup", #selector(showChecklist), symbol: "checklist")) }

        menu.addItem(.separator())
        let copy = item("menu.copyLast", #selector(copyLast), symbol: "doc.on.doc")
        copy.isEnabled = model.controller.lastResult != nil
        menu.addItem(copy)
        menu.addItem(item("menu.settings", #selector(showSettings), key: ",", symbol: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(item("menu.quit", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp, symbol: "power"))
    }

    private func item(_ key: String, _ action: Selector, key equivalent: String = "",
                      target: AnyObject? = nil, symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: ui(key), action: action, keyEquivalent: equivalent)
        item.target = target ?? self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    /// Цветная точка перед строкой статуса: зелёная — готово, красная — запись, оранжевая — нужно внимание.
    private static func dot(for status: MenuStatus) -> NSImage? {
        let config = NSImage.SymbolConfiguration(paletteColors: [status.indicatorColor])
        return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    @objc private func showSettings() { openSettings() }
    @objc private func showChecklist() { openChecklist() }
    @objc private func copyLast() { model.copyLastDictation() }
    @objc private func openMicrophonePrivacy() { model.permissions.openSettings(.microphone) }
    @objc private func openAccessibilityPrivacy() { model.permissions.openSettings(.accessibility) }
}
