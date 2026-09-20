import Foundation
import CoreGraphics
import ApplicationServices

/// Watches one modifier key through a pass-through CGEventTap (needs Accessibility only).
public final class HotkeyMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var machine = HotkeyStateMachine()
    private var hotkey: Hotkey = .rightOption
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?
    private var onCancel: (() -> Void)?
    private var heldKeys = HeldKeys()

    public init() {}

    deinit { stop() }

    /// True while the tap is installed and enabled.
    public var isAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    public func start(hotkey: Hotkey,
                      onPress: @escaping () -> Void,
                      onRelease: @escaping () -> Void,
                      onCancel: @escaping () -> Void) {
        stop()
        lock.lock()
        self.hotkey = hotkey
        self.onPress = onPress
        self.onRelease = onRelease
        self.onCancel = onCancel
        machine = HotkeyStateMachine()
        heldKeys.reset()
        lock.unlock()

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        // Active (not listen-only) tap: only Accessibility is required, no Input Monitoring.
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lock.lock()
        self.tap = tap
        self.source = source
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        let tap = self.tap, source = self.source
        self.tap = nil; self.source = nil
        onPress = nil; onRelease = nil; onCancel = nil
        lock.unlock()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock(); let tap = self.tap; lock.unlock()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            lock.lock(); heldKeys.reset(); lock.unlock()
            return
        }
        let kind: HotkeyClassifier.Kind = switch type {
        case .flagsChanged: .flagsChanged
        case .keyDown: .keyDown
        case .keyUp: .other
        default: .other
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        lock.lock()
        let now = ProcessInfo.processInfo.systemUptime
        let flags = event.flags.rawValue
        switch type {
        case .keyDown: heldKeys.keyDown(code, at: now)
        case .keyUp: heldKeys.keyUp(code)
        case .flagsChanged:
            let triggerHeld = code == HotkeyClassifier.keyCode(for: hotkey)
                && (flags & HotkeyClassifier.mask(for: hotkey)) != 0
            // Trigger-down itself is judged first, against keys held before it.
            if !triggerHeld { heldKeys.flagsChanged(anyModifierDown: HotkeyClassifier.anyModifierDown(flags: flags), triggerHeld: false) }
        default: break
        }
        let output: HotkeyOutput?
        let (press, release, cancel) = (onPress, onRelease, onCancel)
        if let ev = HotkeyClassifier.classify(kind: kind,
                                              keyCode: code,
                                              flags: flags, hotkey: hotkey,
                                              otherKeysHeld: heldKeys.isAnyHeld(at: now)) {
            output = machine.handle(ev)
        } else { output = nil }
        lock.unlock()
        switch output {
        case .press: press?()
        case .release: release?()
        case .cancel: cancel?()
        case nil: break
        }
    }
}
