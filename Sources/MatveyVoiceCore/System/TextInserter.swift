import Foundation
import AppKit
import ApplicationServices

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
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedOnly(reason: String(localized: "insert.noAccess", table: "System", bundle: .main))
        }
        let saved = Self.snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChange = pasteboard.changeCount
        sendPaste()
        try? await Task.sleep(for: restoreDelay)
        // Restore only if nobody else wrote to the pasteboard meanwhile.
        if pasteboard.changeCount == ourChange {
            Self.restore(saved, to: pasteboard)
        }
        return .inserted
    }

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
        let vKey: CGKeyCode = 9
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
