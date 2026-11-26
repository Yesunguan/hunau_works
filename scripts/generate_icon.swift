#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate_icon.swift <output_iconset_dir>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int) -> NSImage {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: size)
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = CGFloat(pixelSize)
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = rect.width * 0.24
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Subtle drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.025), blur: s * 0.055, color: NSColor.black.withAlphaComponent(0.32).cgColor)
    ctx.addPath(squircle)
    ctx.setFillColor(NSColor(calibratedRed: 0.14, green: 0.28, blue: 0.68, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to rounded icon tile
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // Deep liquid sapphire-violet base gradient
    let bgColors = [
        NSColor(calibratedRed: 0.14, green: 0.45, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.92, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.09, green: 0.65, blue: 0.85, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    // Soft internal luminous orb
    let glowColors = [
        NSColor(calibratedRed: 0.65, green: 0.92, blue: 1.0, alpha: 0.65).cgColor,
        NSColor(calibratedRed: 0.65, green: 0.92, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    if let radial = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            radial,
            startCenter: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.22),
            startRadius: 0,
            endCenter: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.22),
            endRadius: rect.width * 0.68,
            options: []
        )
    }

    // Frosted inner floating glass card
    let cardRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.14)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRect.width * 0.22, cornerHeight: cardRect.width * 0.22, transform: nil)
    ctx.addPath(cardPath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.fillPath()

    ctx.addPath(cardPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.62).cgColor)
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.strokePath()

    // Crisp luminous checkmark inside card
    let checkPath = CGMutablePath()
    checkPath.move(to: CGPoint(x: s * 0.34, y: s * 0.50))
    checkPath.addLine(to: CGPoint(x: s * 0.46, y: s * 0.38))
    checkPath.addLine(to: CGPoint(x: s * 0.68, y: s * 0.63))

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.035, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    ctx.addPath(checkPath)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(max(2.0, s * 0.072))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // Top specular glass highlight curve
    let highlightRect = CGRect(x: rect.minX - rect.width * 0.1, y: rect.midY + rect.height * 0.12, width: rect.width * 1.2, height: rect.height * 0.6)
    ctx.addEllipse(in: highlightRect)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    ctx.fillPath()

    ctx.restoreGState()

    // Outer specular glass rim
    ctx.addPath(squircle)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(max(1.0, s * 0.015))
    ctx.strokePath()

    image.unlockFocus()
    return image
}

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in sizes {
    let img = renderIcon(pixelSize: entry.px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(entry.name)\n", stderr)
        exit(1)
    }
    try png.write(to: outputDir.appendingPathComponent(entry.name))
}

print("Generated iconset at \(outputDir.path)")
