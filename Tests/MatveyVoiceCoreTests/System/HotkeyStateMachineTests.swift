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

@Suite struct HotkeyHeldOthersTests {
    @Test func triggerPressedWhileOtherHeldEmitsNothingAndNoRelease() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.triggerDownWithOthersHeld) == nil)
        #expect(m.handle(.triggerUp) == nil)
        #expect(m.handle(.triggerDown) == .press)
    }

    @Test func classifierFlagsHeldModifierAndHeldKey() {
        // right option (0x40) plus left shift (0x2) already down
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0x42, hotkey: .rightOption) == .triggerDownWithOthersHeld)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0x40, hotkey: .rightOption, otherKeysHeld: true) == .triggerDownWithOthersHeld)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0x40, hotkey: .rightOption) == .triggerDown)
    }
}

@Suite struct HeldKeysTests {
    @Test func heldKeyIsReported() {
        var h = HeldKeys()
        h.keyDown(0, at: 10)
        #expect(h.isAnyHeld(at: 10.5))
        h.keyUp(0)
        #expect(!h.isAnyHeld(at: 10.5))
    }

    @Test func stuckKeyClearsWhenNoModifiersAndTriggerNotHeld() {
        var h = HeldKeys()
        h.keyDown(48, at: 10)  // Tab after Cmd+Tab, keyUp never arrived
        h.flagsChanged(anyModifierDown: false, triggerHeld: false)
        #expect(!h.isAnyHeld(at: 10.1))
    }

    @Test func notClearedWhileTriggerOrModifierHeld() {
        var h = HeldKeys()
        h.keyDown(0, at: 10)
        h.flagsChanged(anyModifierDown: true, triggerHeld: true)
        h.flagsChanged(anyModifierDown: true, triggerHeld: false)
        h.flagsChanged(anyModifierDown: false, triggerHeld: true)
        #expect(h.isAnyHeld(at: 10.1))
    }

    @Test func staleEntriesExpire() {
        var h = HeldKeys()
        h.keyDown(0, at: 10)
        #expect(h.isAnyHeld(at: 11.9))
        #expect(!h.isAnyHeld(at: 12.1))
        h.keyDown(0, at: 12)  // autorepeat refreshes
        #expect(h.isAnyHeld(at: 13.5))
    }

    @Test func heldKeyStillSilencesPressThroughClassifier() {
        var h = HeldKeys()
        h.keyDown(0, at: 10)
        let ev = HotkeyClassifier.classify(kind: .flagsChanged, keyCode: 61, flags: 0x40, hotkey: .rightOption,
                                           otherKeysHeld: h.isAnyHeld(at: 10.2))
        var m = HotkeyStateMachine()
        #expect(m.handle(ev!) == nil)
        #expect(m.handle(.triggerUp) == nil)
    }
}

@Suite struct HotkeyClassifierAllKeysTests {
    @Test(arguments: [
        (Hotkey.rightCommand, Int64(54), UInt64(0x10)),
        (Hotkey.rightControl, Int64(62), UInt64(0x2000)),
    ])
    func othersHeldSilencesTrigger(hotkey: Hotkey, code: Int64, mask: UInt64) {
        // left shift (0x2) already down
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: code, flags: mask | 0x2, hotkey: hotkey) == .triggerDownWithOthersHeld)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: code, flags: mask, hotkey: hotkey, otherKeysHeld: true) == .triggerDownWithOthersHeld)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: code, flags: mask, hotkey: hotkey) == .triggerDown)
    }

    @Test(arguments: [
        (Hotkey.rightOption, Int64(61), UInt64(0x40)),
        (Hotkey.rightCommand, Int64(54), UInt64(0x10)),
        (Hotkey.rightControl, Int64(62), UInt64(0x2000)),
        (Hotkey.fn, Int64(63), UInt64(0x800000)),
    ])
    func downAndUp(hotkey: Hotkey, code: Int64, mask: UInt64) {
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: code, flags: mask, hotkey: hotkey) == .triggerDown)
        #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: code, flags: 0, hotkey: hotkey) == .triggerUp)
        // the other three keys' codes are not this trigger
        for other in [Int64(61), 54, 62, 63] where other != code {
            #expect(HotkeyClassifier.classify(kind: .flagsChanged, keyCode: other, flags: mask, hotkey: hotkey) == .otherKeyDown)
        }
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
