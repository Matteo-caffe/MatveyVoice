import Foundation

/// Raw input as seen by the state machine, already reduced to what matters.
public enum HotkeyEvent: Sendable, Equatable {
    case triggerDown
    /// Триггер нажат, но другие клавиши или модификаторы уже удерживались: это не диктовка.
    case triggerDownWithOthersHeld
    case triggerUp
    /// Any other key or modifier changed while the trigger might be held.
    case otherKeyDown
}

public enum HotkeyOutput: Sendable, Equatable {
    case press, release, cancel
}

/// Pure logic: a combo with any other key turns the release into a cancel.
public struct HotkeyStateMachine: Sendable {
    private enum Phase { case idle, held, cancelled }
    private var phase: Phase = .idle

    public init() {}

    public mutating func handle(_ event: HotkeyEvent) -> HotkeyOutput? {
        switch (phase, event) {
        case (.idle, .triggerDown):
            phase = .held
            return .press
        case (.idle, .triggerDownWithOthersHeld):
            phase = .cancelled
            return nil
        case (.held, .triggerUp):
            phase = .idle
            return .release
        case (.held, .otherKeyDown):
            phase = .cancelled
            return .cancel
        case (.cancelled, .triggerUp):
            phase = .idle
            return nil
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

    /// - Parameter otherKeysHeld: удерживается ли обычная (не модификатор) клавиша.
    public static func classify(kind: Kind, keyCode: Int64, flags: UInt64, hotkey: Hotkey,
                                otherKeysHeld: Bool = false) -> HotkeyEvent? {
        switch kind {
        case .keyDown:
            return .otherKeyDown
        case .flagsChanged:
            if keyCode == Self.keyCode(for: hotkey) {
                guard (flags & mask(for: hotkey)) != 0 else { return .triggerUp }
                var others = (allDeviceModifiers | secondaryFn) & ~mask(for: hotkey)
                if hotkey == .fn { others = allDeviceModifiers }
                return (flags & others) != 0 || otherKeysHeld ? .triggerDownWithOthersHeld : .triggerDown
            }
            return .otherKeyDown
        case .other:
            return nil
        }
    }
}
