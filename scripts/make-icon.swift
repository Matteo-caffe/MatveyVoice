// Draws the MatveyVoice app icon (a graphite tile with a voice waveform) into PNG files.
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
    // Tile: dark graphite with a faint top-to-bottom falloff and a hairline edge.
    let tile = NSRect(x: 4*u, y: 4*u, width: 92*u, height: 92*u)
    let bg = NSBezierPath(roundedRect: tile, xRadius: 21*u, yRadius: 21*u)
    NSGradient(starting: NSColor(white: 0.22, alpha: 1), ending: NSColor(white: 0.10, alpha: 1))!.draw(in: bg, angle: -90)
    NSColor(white: 1, alpha: 0.10).setStroke()
    let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 0.5*u, dy: 0.5*u), xRadius: 20.5*u, yRadius: 20.5*u)
    edge.lineWidth = 1*u
    edge.stroke()
    // Waveform: seven rounded bars of an uneven, speech-like height; the tallest carries the accent.
    let heights: [CGFloat] = [0.30, 0.62, 0.44, 1.00, 0.58, 0.80, 0.34]
    let accent = 3
    let barWidth = 5.2*u, gap = 4.2*u, maxHeight = 50*u
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = 50*u - total / 2
    for (index, h) in heights.enumerated() {
        let height = max(barWidth, maxHeight * h)
        let rect = NSRect(x: x, y: 50*u - height / 2, width: barWidth, height: height)
        (index == accent ? NSColor(red: 0.90, green: 0.27, blue: 0.06, alpha: 1) : NSColor(white: 1, alpha: 0.92)).setFill()
        NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + gap
    }
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
