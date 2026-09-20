import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Pastes text into the frontmost app: pasteboard + synthetic Cmd+V, then restores the pasteboard.
public final class TextInserter: TextInserting, @unchecked Sendable {
    private let pasteboard: NSPasteboard
    private let isTrusted: @Sendable () -> Bool
    private let sendPaste: @Sendable () -> Void
    private let restoreDelay: Duration

    public init(pasteboard: NSPasteboard = .general,
                isTrusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
                sendPaste: @escaping @Sendable () -> Void = TextInserter.postCommandV,
                restoreDelay: Duration = .milliseconds(250)) {
        self.pasteboard = pasteboard
        self.isTrusted = isTrusted
        self.sendPaste = sendPaste
        self.restoreDelay = restoreDelay
    }

    public func insert(_ text: String) async throws -> InsertResult {
        guard isTrusted() else {
            // Пользователь сам вставит текст: пометка «временный» не нужна, но и прежнее не восстанавливаем.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedOnly(reason: String(localized: "insert.noAccess", table: "System", bundle: .main))
        }
        let saved = Self.snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Менеджеры буфера обмена (nspasteboard.org) не должны сохранять текст диктовки.
        pasteboard.setData(Data(), forType: Self.transientType)
        pasteboard.setData(Data(), forType: Self.concealedType)
        let ourChange = pasteboard.changeCount
        sendPaste()
        // Отмена вызывающей задачи не должна приводить к немедленному восстановлению:
        // приложение-получатель ещё может читать буфер. Ждём в отдельной задаче.
        let delay = restoreDelay
        await Task.detached { try? await Task.sleep(for: delay) }.value
        // Restore only if nobody else wrote to the pasteboard meanwhile.
        if pasteboard.changeCount == ourChange {
            Self.restore(saved, to: pasteboard)
        }
        return .inserted
    }

    public static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    public static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Every item with every type it carries.
    static func snapshot(_ pb: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }

    static func restore(_ saved: [[(NSPasteboard.PasteboardType, Data)]], to pb: NSPasteboard) {
        pb.clearContents()
        guard !saved.isEmpty else { return }
        let items = saved.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }

    /// Cmd+V only; never Return.
    @Sendable public static func postCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = cachedKeyCodeForV()
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}

private let vKeyLock = NSLock()
nonisolated(unsafe) private var vKeyCache: CGKeyCode?

extension TextInserter {
    /// TIS-вызовы допустимы только на главном потоке: определяем код один раз там и кешируем.
    static func cachedKeyCodeForV() -> CGKeyCode {
        vKeyLock.lock(); let cached = vKeyCache; vKeyLock.unlock()
        if let cached { return cached }
        let code: CGKeyCode = Thread.isMainThread ? keyCodeForV() : DispatchQueue.main.sync { keyCodeForV() }
        vKeyLock.lock(); vKeyCache = code; vKeyLock.unlock()
        return code
    }
}

extension TextInserter {
    /// Код клавиши «V» в текущей раскладке (Dvorak, AZERTY и т. д.); запасной путь — 9 (ANSI QWERTY).
    static func keyCodeForV() -> CGKeyCode {
        let fallback: CGKeyCode = 9
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return fallback }
        let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return fallback }
        return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            for code in 0..<UInt16(128) {
                var dead: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0,
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                            &dead, chars.count, &length, &chars)
                if status == noErr, length == 1, chars[0] == UniChar(UInt8(ascii: "v")) { return CGKeyCode(code) }
            }
            return fallback
        }
    }
}
