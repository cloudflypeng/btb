#!/usr/bin/env swift
import AppKit

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let outDir = URL(fileURLWithPath: "App/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

func makeIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = CGFloat(size) * 0.055
    let bgRect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.18, green: 0.48, blue: 1.0, alpha: 1),
        ending: NSColor(calibratedRed: 0.49, green: 0.24, blue: 0.94, alpha: 1)
    )!
    gradient.draw(in: bg, angle: -50)

    NSColor.white.withAlphaComponent(0.16).setStroke()
    bg.lineWidth = max(1, CGFloat(size) * 0.008)
    bg.stroke()

    let center = NSPoint(x: CGFloat(size) * 0.535, y: CGFloat(size) * 0.5)
    let w = CGFloat(size) * 0.30
    let h = CGFloat(size) * 0.37
    let play = NSBezierPath()
    play.move(to: NSPoint(x: center.x - w / 2, y: center.y - h / 2))
    play.line(to: NSPoint(x: center.x - w / 2, y: center.y + h / 2))
    play.line(to: NSPoint(x: center.x + w / 2, y: center.y))
    play.close()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = CGFloat(size) * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.012)
    shadow.set()
    NSColor.white.setFill()
    play.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for (size, name) in specs {
    try makeIcon(size: size).write(to: outDir.appendingPathComponent(name))
    print("wrote \(name) (\(size)x\(size))")
}
