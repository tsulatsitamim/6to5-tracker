import AppKit

// Generates Resources/AppIcon.png (1024x1024) for PresenceTracker.
// Run from the repo root: swift Scripts/gen-icon.swift

let size = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("error: could not create bitmap")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
defer { NSGraphicsContext.restoreGraphicsState() }

// Background: rounded rect with a top-to-bottom indigo gradient.
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: CGFloat(size) * 0.225, yRadius: CGFloat(size) * 0.225)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.27, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.34, blue: 0.60, alpha: 1)
])!
gradient.draw(from: NSPoint(x: CGFloat(size) / 2, y: CGFloat(size)), to: NSPoint(x: CGFloat(size) / 2, y: 0), options: [])

// Person silhouette (presence).
NSColor.white.setFill()

// Head.
let headRect = NSRect(x: CGFloat(size) * 0.30, y: CGFloat(size) * 0.50, width: CGFloat(size) * 0.40, height: CGFloat(size) * 0.40)
NSBezierPath(ovalIn: headRect).fill()

// Shoulders.
let bodyRect = NSRect(x: CGFloat(size) * 0.18, y: CGFloat(size) * 0.10, width: CGFloat(size) * 0.64, height: CGFloat(size) * 0.28)
NSBezierPath(roundedRect: bodyRect, xRadius: CGFloat(size) * 0.14, yRadius: CGFloat(size) * 0.14).fill()

// "Live" presence indicator: white ring + green dot, top-right.
let dotCenter = NSPoint(x: CGFloat(size) * 0.78, y: CGFloat(size) * 0.78)
let dotRadius = CGFloat(size) * 0.08

let outer = NSRect(
    x: dotCenter.x - dotRadius * 1.6,
    y: dotCenter.y - dotRadius * 1.6,
    width: dotRadius * 3.2,
    height: dotRadius * 3.2
)
NSColor.white.setFill()
NSBezierPath(ovalIn: outer).fill()

let inner = NSRect(
    x: dotCenter.x - dotRadius,
    y: dotCenter.y - dotRadius,
    width: dotRadius * 2,
    height: dotRadius * 2
)
NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.50, alpha: 1).setFill()
NSBezierPath(ovalIn: inner).fill()

// Write PNG.
guard let png = rep.representation(using: .png, properties: [:]) else {
    print("error: could not encode PNG")
    exit(1)
}
let out = URL(fileURLWithPath: "Resources/AppIcon.png")
try! png.write(to: out)
print("wrote \(out.path)")