import Testing
import AppKit
import Carbon.HIToolbox
@testable import MatveyVoiceCore

private final class Counter: @unchecked Sendable { var pastes = 0 }
private final class PB: @unchecked Sendable { let pb: NSPasteboard; init(_ p: NSPasteboard) { pb = p } }

@Suite(.serialized) struct TextInserterTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("mv.test.\(UUID().uuidString)"))
    }

    @Test func withoutAccessOnlyCopiesAndDoesNotPaste() async throws {
        let pb = makePasteboard()
        let c = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { false }, sendPaste: { c.pastes += 1 }, restoreDelay: .milliseconds(1))
        let r = try await ins.insert("привет")
        guard case .copiedOnly = r else { Issue.record("expected copiedOnly, got \(r)"); return }
        #expect(c.pastes == 0)
        #expect(pb.string(forType: .string) == "привет")
    }

    @Test func secureFieldBlocksPasteAndLeavesPasteboardUntouched() async throws {
        let pb = makePasteboard()
        pb.clearContents()
        pb.setString("old text", forType: .string)
        let before = pb.changeCount
        let c = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { true },
                               sendPaste: { c.pastes += 1 }, restoreDelay: .milliseconds(1))
        let r = try await ins.insert("hunter2")
        #expect(r == .blockedSecureField)
        #expect(c.pastes == 0)
        #expect(pb.changeCount == before)
        #expect(pb.string(forType: .string) == "old text")
    }

    @Test func pastesOnceAndRestoresAllTypes() async throws {
        let pb = makePasteboard()
        let item = NSPasteboardItem()
        item.setString("old text", forType: .string)
        item.setData(Data([1, 2, 3]), forType: NSPasteboard.PasteboardType("com.example.custom"))
        pb.writeObjects([item])
        let c = Counter()
        let seen = Counter()
        let box = PB(pb)
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false }, sendPaste: {
            c.pastes += 1
            if box.pb.string(forType: .string) == "new text" { seen.pastes += 1 }
        }, restoreDelay: .milliseconds(1))
        let r = try await ins.insert("new text")
        #expect(r == .inserted)
        #expect(c.pastes == 1)
        #expect(seen.pastes == 1)  // our text was on the pasteboard at paste time
        #expect(pb.string(forType: .string) == "old text")
        #expect(pb.data(forType: NSPasteboard.PasteboardType("com.example.custom")) == Data([1, 2, 3]))
    }

    @Test func dictatedTextIsMarkedTransientAndConcealedOnlyWhileOnPasteboard() async throws {
        let pb = makePasteboard()
        let box = PB(pb)
        let during = Marks()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false }, sendPaste: {
            let types = box.pb.types ?? []
            during.transient = types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            during.concealed = types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        }, restoreDelay: .milliseconds(1))
        #expect(TextInserter.transientType.rawValue == "org.nspasteboard.TransientType")
        #expect(TextInserter.concealedType.rawValue == "org.nspasteboard.ConcealedType")
        _ = try await ins.insert("secret")
        #expect(during.transient && during.concealed)
        let after = pb.types ?? []
        #expect(!after.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
        #expect(!after.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
    }

    @Test func copiedOnlyKeepsTextWithoutMarks() async throws {
        let pb = makePasteboard()
        let ins = TextInserter(pasteboard: pb, isTrusted: { false }, sendPaste: {}, restoreDelay: .milliseconds(1))
        _ = try await ins.insert("keep me")
        #expect(pb.string(forType: .string) == "keep me")
        let types = pb.types ?? []
        #expect(!types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
        #expect(!types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
    }

    @Test func cancellationDoesNotRestoreBeforeTheDelay() async throws {
        let pb = makePasteboard()
        pb.setString("old", forType: .string)
        let box = PB(pb)
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false }, sendPaste: {}, restoreDelay: .milliseconds(300))
        let started = ContinuousClock.now
        let task = Task { try await ins.insert("new") }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        try await Task.sleep(for: .milliseconds(60))
        // still inside the delay: our text must remain for the target app to read
        #expect(box.pb.string(forType: .string) == "new")
        _ = try await task.value
        #expect(ContinuousClock.now - started >= .milliseconds(280))
        #expect(pb.string(forType: .string) == "old")
    }

    @Test func pressReturnFalseNeverSendsReturn() async throws {
        let pb = makePasteboard()
        let returns = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false },
                               sendPaste: {}, sendReturn: { _ in returns.pastes += 1 },
                               restoreDelay: .milliseconds(1), returnDelay: .milliseconds(1))
        let r = try await ins.insert("hello", pressReturn: false, commandReturn: false)
        #expect(r == .inserted)
        #expect(returns.pastes == 0)
    }

    @Test func pressReturnTrueSendsReturnAfterPaste() async throws {
        let pb = makePasteboard()
        let order = Counter()
        let pasteOrder = Counter()
        let returnOrder = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false }, sendPaste: {
            order.pastes += 1; pasteOrder.pastes = order.pastes
        }, sendReturn: { _ in
            order.pastes += 1; returnOrder.pastes = order.pastes
        }, restoreDelay: .milliseconds(1), returnDelay: .milliseconds(1))
        let r = try await ins.insert("hello", pressReturn: true, commandReturn: false)
        #expect(r == .inserted)
        #expect(pasteOrder.pastes == 1)
        #expect(returnOrder.pastes == 2)
    }

    @Test func commandReturnFlagIsForwardedToSendReturn() async throws {
        let pb = makePasteboard()
        let seenCommand = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { false }, sendPaste: {},
                               sendReturn: { withCommand in seenCommand.pastes = withCommand ? 1 : 0 },
                               restoreDelay: .milliseconds(1), returnDelay: .milliseconds(1))
        _ = try await ins.insert("hello", pressReturn: true, commandReturn: true)
        #expect(seenCommand.pastes == 1)
    }

    @Test(arguments: [false, true]) func returnEventsCarryOnlyTheRequestedModifier(withCommand: Bool) {
        let events = TextInserter.returnEvents(withCommand: withCommand)
        #expect(events.count == 2)
        for e in events {
            #expect(e.flags == (withCommand ? .maskCommand : []))
            #expect(e.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Return))
        }
    }

    @Test func pressReturnIsSkippedWithoutAccess() async throws {
        let pb = makePasteboard()
        let returns = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { false }, sendReturn: { _ in returns.pastes += 1 },
                               restoreDelay: .milliseconds(1))
        _ = try await ins.insert("hello", pressReturn: true, commandReturn: false)
        #expect(returns.pastes == 0)
    }

    @Test func pressReturnIsSkippedForSecureField() async throws {
        let pb = makePasteboard()
        let returns = Counter()
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, isSecureFieldFocused: { true },
                               sendReturn: { _ in returns.pastes += 1 }, restoreDelay: .milliseconds(1))
        _ = try await ins.insert("hello", pressReturn: true, commandReturn: false)
        #expect(returns.pastes == 0)
    }
}

private final class Marks: @unchecked Sendable { var transient = false; var concealed = false }
