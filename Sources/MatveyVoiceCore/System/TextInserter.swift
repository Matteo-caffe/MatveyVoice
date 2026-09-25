import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Pastes text into the frontmost app: pasteboard + synthetic Cmd+V, then restores the pasteboard.
public final class TextInserter: TextInserting, @unchecked Sendable {
    private let pasteboard: NSPasteboard
    private let isTrusted: @Sendable () -> Bool
    private let isSecureFieldFocused: @Sendable () -> Bool
    private let sendPaste: @Sendable () -> Void
    private let sendReturn: @Sendable (Bool) -> Void
    private let restoreDelay: Duration
    private let returnDelay: Duration

    public init(pasteboard: NSPasteboard = .general,
                isTrusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
                isSecureFieldFocused: @escaping @Sendable () -> Bool = TextInserter.focusedElementIsSecure,
                sendPaste: @escaping @Sendable () -> Void = TextInserter.postCommandV,
                sendReturn: @escaping @Sendable (Bool) -> Void = TextInserter.postReturn(withCommand:),
                restoreDelay: Duration = .milliseconds(250),
                returnDelay: Duration = .milliseconds(150)) {
        self.pasteboard = pasteboard
        self.isTrusted = isTrusted
        self.isSecureFieldFocused = isSecureFieldFocused
        self.sendPaste = sendPaste
        self.sendReturn = sendReturn
        self.restoreDelay = restoreDelay
        self.returnDelay = returnDelay
    }

    public func insert(_ text: String, pressReturn: Bool, commandReturn: Bool) async throws -> InsertResult {
        guard isTrusted() else {
            // Пользователь сам вставит текст: пометка «временный» не нужна, но и прежнее не восстанавливаем.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedOnly(reason: String(localized: "insert.noAccess", table: "System", bundle: .main))
        }
        // В поле пароля не вставляем и буфер не трогаем: пароль не должен пройти через буфер обмена.
        if isSecureFieldFocused() { return .blockedSecureField }
        let saved = Self.snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Менеджеры буфера обмена (nspasteboard.org) не должны сохранять текст диктовки.
        pasteboard.setData(Data(), forType: Self.transientType)
        pasteboard.setData(Data(), forType: Self.concealedType)
        let ourChange = pasteboard.changeCount
        sendPaste()
        if pressReturn {
            // Пауза, чтобы принимающее приложение успело обработать вставку до Return.
            // Нажатие идёт в отдельной задаче: postReturn держит клавишу ~30 мс и не должен блокировать вызывающего.
            let delay = returnDelay, send = sendReturn
            await Task.detached { try? await Task.sleep(for: delay); send(commandReturn) }.value
        }
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

    @Sendable public static func focusedElementIsSecure() -> Bool {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSubroleAttribute as CFString, &subrole) == .success else { return false }
        return (subrole as? String) == kAXSecureTextFieldSubrole
    }

    /// Cmd+V only; Return is a separate, explicit action (see `postReturn`), never implied by paste.
    @Sendable public static func postCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = cachedKeyCodeForV()
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// Hardware Return for voice-send (`pressReturn`): posted at the HID level, where a physical keyboard
    /// enters the event stream, with a short hold between down and up like a real press. `kVK_Return` is a
    /// physical key position, unaffected by keyboard layout. `withCommand` is for apps that send with ⌘+Return.
    @Sendable public static func postReturn(withCommand: Bool) {
        let events = returnEvents(withCommand: withCommand)
        guard events.count == 2 else { return }
        events[0].post(tap: .cghidEventTap)
        usleep(30_000)
        events[1].post(tap: .cghidEventTap)
    }

    /// Flags are always assigned explicitly: a fresh keyboard CGEvent carries a stray 0x20000000 bit
    /// that Telegram reads as a modifier, so a bare Return inserted a newline instead of sending.
    static func returnEvents(withCommand: Bool) -> [CGEvent] {
        let src = CGEventSource(stateID: .hidSystemState)
        return [true, false].compactMap { down in
            let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Return), keyDown: down)
            e?.flags = withCommand ? .maskCommand : []
            return e
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
