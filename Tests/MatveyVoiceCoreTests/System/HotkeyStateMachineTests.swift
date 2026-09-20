import Testing
@testable import MatveyVoiceCore

@Suite struct HotkeyStateMachineTests {
    @Test func pressThenReleaseEmitsPressAndRelease() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.triggerDown) == .press)
        #expect(m.handle(.triggerUp) == .release)
    }

    @Test func otherKeyWhileHeldCancelsInsteadOfRelease() {
        var m = HotkeyStateMachine()
        _ = m.handle(.triggerDown)
        #expect(m.handle(.otherKeyDown) == .cancel)
        #expect(m.handle(.triggerUp) == nil)
        // machine is usable again afterwards
        #expect(m.handle(.triggerDown) == .press)
        #expect(m.handle(.triggerUp) == .release)
    }

    @Test func otherKeyWithoutTriggerIsIgnored() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.otherKeyDown) == nil)
        #expect(m.handle(.triggerDown) == .press)
    }

    @Test func repeatedDownWhileHeldIsIgnored() {
        var m = HotkeyStateMachine()
        _ = m.handle(.triggerDown)
        #expect(m.handle(.triggerDown) == nil)
    }
}

@Suite struct HotkeyClassifierTests {
    @Test func rightOptionDownAndUpByKeyCode() {
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0x40, hotkey: .rightOption) == .triggerDown)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0, hotkey: .rightOption) == .triggerUp)
    }

    @Test func leftOptionIsNotTheTrigger() {
        // keyCode 58 = left option
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 58, flags: 0x20, hotkey: .rightOption) == .otherKeyDown)
    }

    @Test func fnUsesSecondaryFnFlag() {
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 63, flags: 0x800000, hotkey: .fn) == .triggerDown)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 63, flags: 0, hotkey: .fn) == .triggerUp)
    }

    @Test func letterKeyIsOtherKey() {
        #expect(HotkeyClassifier.classify(kind: .keyDown, keyCode: 0, flags: 0x40, hotkey: .rightOption) == .otherKeyDown)
    }
}
