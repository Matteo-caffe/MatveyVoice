import Foundation

/// Raw input as seen by the state machine, already reduced to what matters.
public enum HotkeyEvent: Sendable, Equatable {
    case triggerDown
    /// Триггер нажат, но другие клавиши или модификаторы уже удерживались: это не диктовка.
    case triggerDownWithOthersHeld
    /// Триггер нажат, пока удерживается только Control: запись без удержания.
    case triggerDownWithLatch
    case triggerUp
    /// Control нажат, пока удерживается только триггер: идущая запись продолжается без удержания.
    case latchDown
    case escapeDown
    /// Any other key or modifier changed while the trigger might be held.
    case otherKeyDown
}

public enum HotkeyOutput: Sendable, Equatable {
    /// `latch` — начать запись без удержания или перевести в него идущую.
    case press, release, cancel, latch
}

/// Pure logic: a combo with any other key turns the release into a cancel. Control + trigger
/// latches the recording: releasing the keys no longer stops it, the next trigger press does,
/// Escape cancels it.
public struct HotkeyStateMachine: Sendable {
    private enum Phase {
        case idle, held, cancelled
        /// Latched, the keys are still down.
        case latchedHeld
        /// Latched, keys released: recording without holding anything.
        case handsFree
        /// The press that stopped hands-free recording; waits for its release.
        case stopping
    }
    private var phase: Phase = .idle

    public init() {}

    public mutating func handle(_ event: HotkeyEvent) -> HotkeyOutput? {
        switch (phase, event) {
        case (.idle, .triggerDown):
            phase = .held
            return .press
        case (.idle, .triggerDownWithLatch):
            phase = .latchedHeld
            return .latch
        case (.idle, .triggerDownWithOthersHeld):
            phase = .cancelled
            return nil
        case (.held, .triggerUp):
            phase = .idle
            return .release
        case (.held, .latchDown):
            phase = .latchedHeld
            return .latch
        case (.held, .otherKeyDown), (.held, .escapeDown), (.latchedHeld, .escapeDown):
            phase = .cancelled
            return .cancel
        case (.cancelled, .triggerUp):
            phase = .idle
            return nil
        case (.latchedHeld, .triggerUp):
            phase = .handsFree
            return nil
        case (.handsFree, .triggerDown), (.handsFree, .triggerDownWithLatch), (.handsFree, .triggerDownWithOthersHeld):
            phase = .stopping
            return .press
        case (.handsFree, .escapeDown):
            phase = .idle
            return .cancel
        // If the recording had already ended (time limit), the stopping press started a new
        // hold recording, and this release ends it.
        case (.stopping, .triggerUp):
            phase = .idle
            return .release
        default:
            return nil
        }
    }
}

/// Pure bookkeeping of held non-modifier keys. A missed keyUp (⌘Tab, ⌘Space, screenshots,
/// password fields) must not disable the hotkey for good, so entries expire and the set
/// is cleared once no modifier is down and the trigger is not held.
public struct HeldKeys: Sendable {
    public static let staleAfter: TimeInterval = 2
    private var pressedAt: [Int64: TimeInterval] = [:]

    public init() {}

    public mutating func keyDown(_ code: Int64, at now: TimeInterval) { pressedAt[code] = now }
    public mutating func keyUp(_ code: Int64) { pressedAt[code] = nil }
    public mutating func reset() { pressedAt = [:] }

    /// Call on every flagsChanged. Clears only if no modifier is down and the trigger is not held.
    public mutating func flagsChanged(anyModifierDown: Bool, triggerHeld: Bool) {
        if !anyModifierDown && !triggerHeld { pressedAt = [:] }
    }

    public func isAnyHeld(at now: TimeInterval) -> Bool {
        pressedAt.values.contains { now - $0 < Self.staleAfter }
    }
}

/// Pure translation of a low-level event (type, keyCode, flags) into a HotkeyEvent.
public enum HotkeyClassifier {
    public enum Kind: Sendable { case flagsChanged, keyDown, other }

    // Device-dependent modifier bits (IOKit NX_DEVICE*KEYMASK) and the Fn flag.
    static let deviceRightOption: UInt64 = 0x40
    static let deviceRightCommand: UInt64 = 0x10
    static let deviceRightControl: UInt64 = 0x2000
    static let secondaryFn: UInt64 = 0x800000
    /// Левый и правый Control.
    static let deviceControls: UInt64 = 0x1 | 0x2000
    static let controlKeyCodes: Set<Int64> = [59, 62]
    static let escapeKeyCode: Int64 = 53
    /// Все прочие аппаратные биты модификаторов: левый/правый shift, control, option, command.
    static let allDeviceModifiers: UInt64 = 0x2 | 0x4 | 0x1 | 0x2000 | 0x20 | 0x40 | 0x8 | 0x10

    /// Any modifier (left or right, any kind) currently down according to the raw flags.
    public static func anyModifierDown(flags: UInt64) -> Bool {
        (flags & (allDeviceModifiers | secondaryFn)) != 0
    }

    public static func keyCode(for hotkey: Hotkey) -> Int64 {
        switch hotkey {
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .fn: 63
        }
    }

    static func mask(for hotkey: Hotkey) -> UInt64 {
        switch hotkey {
        case .rightOption: deviceRightOption
        case .rightCommand: deviceRightCommand
        case .rightControl: deviceRightControl
        case .fn: secondaryFn
        }
    }

    /// Modifiers other than the trigger itself.
    static func others(for hotkey: Hotkey) -> UInt64 {
        hotkey == .fn ? allDeviceModifiers : (allDeviceModifiers | secondaryFn) & ~mask(for: hotkey)
    }

    /// Control bits that latch this trigger (for right Control — only the left one).
    static func latchMask(for hotkey: Hotkey) -> UInt64 {
        deviceControls & ~mask(for: hotkey)
    }

    /// - Parameter otherKeysHeld: удерживается ли обычная (не модификатор) клавиша.
    public static func classify(kind: Kind, keyCode: Int64, flags: UInt64, hotkey: Hotkey,
                                otherKeysHeld: Bool = false) -> HotkeyEvent? {
        let held = flags & others(for: hotkey)
        let onlyControlHeld = held != 0 && (held & ~latchMask(for: hotkey)) == 0 && !otherKeysHeld
        switch kind {
        case .keyDown:
            return keyCode == escapeKeyCode ? .escapeDown : .otherKeyDown
        case .flagsChanged:
            let triggerDown = (flags & mask(for: hotkey)) != 0
            if keyCode == Self.keyCode(for: hotkey) {
                guard triggerDown else { return .triggerUp }
                if held == 0 && !otherKeysHeld { return .triggerDown }
                return onlyControlHeld ? .triggerDownWithLatch : .triggerDownWithOthersHeld
            }
            if controlKeyCodes.contains(keyCode), triggerDown, onlyControlHeld { return .latchDown }
            return .otherKeyDown
        case .other:
            return nil
        }
    }
}
