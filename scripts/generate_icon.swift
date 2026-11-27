#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: generate_icon.swift <badge_png_path> <output_iconset_dir>\n", stderr)
    exit(1)
}

let badgePath = CommandLine.arguments[1]
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let badgeImage = NSImage(contentsOfFile: badgePath),
      let badgeCG = badgeImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("ERROR: Failed to load badge image at \(badgePath)\n", stderr)
    exit(1)
}

func renderIcon(pixelSize: Int) -> NSImage {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: size)
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = CGFloat(pixelSize)
    // Standard macOS circular icon scale (~86% of canvas) with soft elevation shadow
    let diameter = s * 0.86
    let origin = (s - diameter) / 2.0
    let targetRect = CGRect(x: origin, y: origin, width: diameter, height: diameter)
    let circlePath = CGPath(ellipseIn: targetRect, transform: nil)

    ctx.interpolationQuality = .high

    // Subtle elevation shadow beneath circular crest
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.016),
        blur: max(1.0, s * 0.032),
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )
    ctx.addPath(circlePath)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Draw crisp circular badge clipped cleanly
    ctx.saveGState()
    ctx.addPath(circlePath)
    ctx.clip()
    ctx.draw(badgeCG, in: targetRect)
    ctx.restoreGState()

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

print("Generated circular iconset at \(outputDir.path)")
