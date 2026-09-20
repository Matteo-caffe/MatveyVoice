import AppKit
import SwiftUI

/// Окна приложения-агента: показать поверх и активировать приложение.
@MainActor
final class WindowPresenter {
    private var window: NSWindow?
    private let makeContent: (@escaping () -> Void) -> NSView
    private let title: String

    init(title: String, content: @escaping (@escaping () -> Void) -> NSView) {
        self.title = title
        self.makeContent = content
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = title
            w.isReleasedWhenClosed = false
            let content = makeContent { [weak self] in self?.window?.close() }
            w.contentView = content
            w.setContentSize(content.fittingSize)
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
