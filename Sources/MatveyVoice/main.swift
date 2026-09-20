import AppKit

MainActor.assumeIsolated {
    if AppDelegate.shouldYieldToOtherInstance() { exit(0) }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
