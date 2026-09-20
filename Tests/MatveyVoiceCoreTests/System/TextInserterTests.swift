import Testing
import AppKit
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

    @Test func pastesOnceAndRestoresAllTypes() async throws {
        let pb = makePasteboard()
        let item = NSPasteboardItem()
        item.setString("old text", forType: .string)
        item.setData(Data([1, 2, 3]), forType: NSPasteboard.PasteboardType("com.example.custom"))
        pb.writeObjects([item])
        let c = Counter()
        let seen = Counter()
        let box = PB(pb)
        let ins = TextInserter(pasteboard: pb, isTrusted: { true }, sendPaste: {
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
}
