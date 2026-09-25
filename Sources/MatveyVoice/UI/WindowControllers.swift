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
            let w = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            // Заголовок остаётся для VoiceOver и переключателя окон, но не рисуется:
            // содержимое доходит до верхнего края, кнопки окна лежат на стекле.
            w.title = title
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isReleasedWhenClosed = false
            // Окно агента должно открываться там, где сейчас пользователь, в том числе поверх полноэкранного
            // приложения: иначе оно остаётся на том рабочем столе, где его открыли раньше, и «ничего не появляется».
            w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            let content = makeContent { [weak self] in self?.window?.close() }
            w.contentView = content
            w.setContentSize(content.fittingSize)
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // SwiftUI сам ставит курсор в первое текстовое поле: окно выходит поверх, и набранное
        // в другом приложении попадает в настройки (так затёрлось слово голосовой отправки).
        // Фокус ставится уже после показа окна, поэтому снимаем его на следующем проходе цикла событий.
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(nil) }
    }
}
