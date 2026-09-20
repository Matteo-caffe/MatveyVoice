import Foundation

/// Raw input as seen by the state machine, already reduced to what matters.
public enum HotkeyEvent: Sendable, Equatable {
    case triggerDown
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

/// Pure translation of a low-level event (type, keyCode, flags) into a HotkeyEvent.
public enum HotkeyClassifier {
    public enum Kind: Sendable { case flagsChanged, keyDown, other }

    // Device-dependent modifier bits (IOKit NX_DEVICE*KEYMASK) and the Fn flag.
    static let deviceRightOption: UInt64 = 0x40
    static let deviceRightCommand: UInt64 = 0x10
    static let deviceRightControl: UInt64 = 0x2000
    static let secondaryFn: UInt64 = 0x800000

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

    public static func classify(kind: Kind, keyCode: Int64, flags: UInt64, hotkey: Hotkey) -> HotkeyEvent? {
        switch kind {
        case .keyDown:
            return .otherKeyDown
        case .flagsChanged:
            if keyCode == Self.keyCode(for: hotkey) {
                return (flags & mask(for: hotkey)) != 0 ? .triggerDown : .triggerUp
            }
            return .otherKeyDown
        case .other:
            return nil
        }
    }
}
