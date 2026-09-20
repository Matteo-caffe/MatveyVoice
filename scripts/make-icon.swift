// Draws the MatveyVoice app icon (a simple microphone) into PNG files.
// Usage: swift scripts/make-icon.swift <output-dir>   (called by make-icon.sh)
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let u = s / 100
    // Background: rounded square with a vertical gradient.
    let bg = NSBezierPath(roundedRect: NSRect(x: 4*u, y: 4*u, width: 92*u, height: 92*u),
                          xRadius: 21*u, yRadius: 21*u)
    NSGradient(starting: NSColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1),
               ending: NSColor(red: 0.53, green: 0.24, blue: 0.80, alpha: 1))!.draw(in: bg, angle: -90)
    NSColor.white.setFill()
    NSColor.white.setStroke()
    // Capsule of the microphone.
    NSBezierPath(roundedRect: NSRect(x: 39*u, y: 42*u, width: 22*u, height: 36*u),
                 xRadius: 11*u, yRadius: 11*u).fill()
    // Holder arc.
    let arc = NSBezierPath()
    arc.lineWidth = 5*u
    arc.lineCapStyle = .round
    arc.appendArc(withCenter: NSPoint(x: 50*u, y: 50*u), radius: 19*u, startAngle: 180, endAngle: 360)
    arc.stroke()
    // Stem and base.
    let stem = NSBezierPath()
    stem.lineWidth = 5*u
    stem.lineCapStyle = .round
    stem.move(to: NSPoint(x: 50*u, y: 31*u)); stem.line(to: NSPoint(x: 50*u, y: 20*u))
    stem.move(to: NSPoint(x: 39*u, y: 20*u)); stem.line(to: NSPoint(x: 61*u, y: 20*u))
    stem.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <iconset-dir>\n".utf8)); exit(1)
}
let dir = CommandLine.arguments[1]
let items: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in items {
    try render(size: px).write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
}
