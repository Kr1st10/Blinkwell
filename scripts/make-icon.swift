import AppKit
let output = CommandLine.arguments[1]
let folder = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(red: 0.23, green: 0.39, blue: 0.29, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: 968, height: 968), xRadius: 222, yRadius: 222).fill()
        NSColor(red: 0.89, green: 0.94, blue: 0.84, alpha: 1).setFill()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 302, y: 300))
        leaf.curve(to: NSPoint(x: 750, y: 762), controlPoint1: NSPoint(x: 180, y: 680), controlPoint2: NSPoint(x: 547, y: 806))
        leaf.curve(to: NSPoint(x: 302, y: 300), controlPoint1: NSPoint(x: 812, y: 411), controlPoint2: NSPoint(x: 558, y: 220))
        leaf.fill()
        NSColor(red: 0.23, green: 0.39, blue: 0.29, alpha: 1).setStroke()
        let stem = NSBezierPath(); stem.move(to: NSPoint(x: 284, y: 270)); stem.line(to: NSPoint(x: 642, y: 633))
        stem.lineWidth = 24; stem.lineCapStyle = .round; stem.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
