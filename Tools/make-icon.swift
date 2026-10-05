#!/usr/bin/env swift
// Draws the app icon and writes Resources/AppIcon.icns.
//
//     swift Tools/make-icon.swift
//
// The icon is generated rather than committed as a binary blob so it is
// reviewable as code and has no third-party asset to license. Run it
// again after changing the drawing; the result is deterministic.
import AppKit
import Foundation

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = repositoryRoot.appendingPathComponent("build/AppIcon.iconset")
let outputURL = repositoryRoot.appendingPathComponent("Resources/AppIcon.icns")

let space = NSColor(calibratedRed: 0.035, green: 0.047, blue: 0.094, alpha: 1)
let oceanTop = NSColor(calibratedRed: 0.106, green: 0.212, blue: 0.361, alpha: 1)
let oceanBottom = NSColor(calibratedRed: 0.043, green: 0.078, blue: 0.149, alpha: 1)
let graticule = NSColor(calibratedRed: 0.439, green: 0.580, blue: 0.769, alpha: 0.5)
let land = NSColor(calibratedRed: 0.408, green: 0.541, blue: 0.639, alpha: 1)
let rim = NSColor(calibratedRed: 0.408, green: 0.627, blue: 0.902, alpha: 1)

/// Rough landmass blobs in a unit square centred on the globe. Purely
/// decorative — the icon is not a map, and nothing reads geography from
/// it.
let landmasses: [[(Double, Double)]] = [
    [(-0.08, 0.46), (0.12, 0.40), (0.22, 0.20), (0.16, 0.02), (0.20, -0.18),
     (0.10, -0.38), (-0.02, -0.26), (-0.04, -0.06), (-0.16, 0.10), (-0.20, 0.32)],
    [(-0.62, 0.30), (-0.40, 0.38), (-0.28, 0.22), (-0.34, 0.02), (-0.50, -0.04),
     (-0.58, 0.10)],
    [(0.34, 0.30), (0.60, 0.26), (0.66, 0.06), (0.52, -0.06), (0.38, 0.06)],
    [(0.30, -0.34), (0.50, -0.30), (0.52, -0.46), (0.36, -0.48)]
]

func drawIcon(size: CGFloat) -> NSBitmapImageRep? {
    let pixels = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = context

    // Rounded-rect plate in the macOS app-icon proportion.
    let inset = size * 0.055
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let plateRadius = size * 0.225
    let platePath = NSBezierPath(roundedRect: plate, xRadius: plateRadius, yRadius: plateRadius)
    space.setFill()
    platePath.fill()

    let centre = NSPoint(x: size / 2, y: size / 2)
    let radius = size * 0.335

    // Atmospheric rim.
    for step in stride(from: 0, to: 10, by: 1) {
        let spread = radius * (1 + Double(step) * 0.016)
        rim.withAlphaComponent(0.05 * (1 - Double(step) / 10)).setStroke()
        let path = NSBezierPath(ovalIn: NSRect(
            x: centre.x - spread, y: centre.y - spread,
            width: spread * 2, height: spread * 2
        ))
        path.lineWidth = size * 0.012
        path.stroke()
    }

    let globeRect = NSRect(
        x: centre.x - radius, y: centre.y - radius,
        width: radius * 2, height: radius * 2
    )
    let globePath = NSBezierPath(ovalIn: globeRect)

    NSGraphicsContext.current?.saveGraphicsState()
    globePath.addClip()
    NSGradient(starting: oceanTop, ending: oceanBottom)?.draw(in: globeRect, angle: -70)

    land.withAlphaComponent(0.92).setFill()
    for blob in landmasses {
        let path = NSBezierPath()
        for (index, point) in blob.enumerated() {
            let location = NSPoint(
                x: centre.x + CGFloat(point.0) * radius,
                y: centre.y + CGFloat(point.1) * radius
            )
            index == 0 ? path.move(to: location) : path.line(to: location)
        }
        path.close()
        path.fill()
    }

    // Graticule: the equator, two parallels, and three meridians drawn
    // as ellipses, which is what they project to on a sphere.
    graticule.setStroke()
    let lineWidth = max(1, size * 0.006)
    for latitude in [-0.62, 0.0, 0.62] {
        let y = centre.y + CGFloat(latitude) * radius
        let halfWidth = radius * CGFloat((1 - latitude * latitude).squareRoot())
        let height = radius * 0.16
        let path = NSBezierPath(ovalIn: NSRect(
            x: centre.x - halfWidth, y: y - height / 2,
            width: halfWidth * 2, height: height
        ))
        path.lineWidth = lineWidth
        path.stroke()
    }
    for factor in [0.0, 0.52, 0.86] {
        let halfWidth = radius * CGFloat(factor)
        let path = NSBezierPath(ovalIn: NSRect(
            x: centre.x - halfWidth, y: centre.y - radius,
            width: max(halfWidth * 2, lineWidth), height: radius * 2
        ))
        path.lineWidth = lineWidth
        path.stroke()
    }
    NSGraphicsContext.current?.restoreGraphicsState()

    // Terminator: the night side, as a soft shadow on the lower right.
    NSGraphicsContext.current?.saveGraphicsState()
    globePath.addClip()
    let shadow = NSBezierPath(ovalIn: globeRect.offsetBy(dx: radius * 0.55, dy: -radius * 0.42))
    NSColor(calibratedRed: 0.016, green: 0.024, blue: 0.055, alpha: 0.55).setFill()
    shadow.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    rim.withAlphaComponent(0.55).setStroke()
    globePath.lineWidth = size * 0.008
    globePath.stroke()

    context.flushGraphics()
    return rep
}

let manager = FileManager.default
try? manager.removeItem(at: iconsetURL)
try manager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try manager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

// The sizes `iconutil` expects for a macOS icon set.
let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for variant in variants {
    guard let rep = drawIcon(size: variant.size),
          let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("error: could not render \(variant.name)\n".utf8))
        exit(1)
    }
    try data.write(to: iconsetURL.appendingPathComponent("\(variant.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconsetURL.path, "--output", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: iconutil failed\n".utf8))
    exit(1)
}

print("Wrote \(outputURL.path)")
