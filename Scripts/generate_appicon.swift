#!/usr/bin/env swift
// scripts/generate_appicon.swift
// Procedurally renders the Optune app icon as a CoreGraphics gradient
// disc with a SF-style mouse glyph centered on top, then writes the
// nine sizes Apple requires for a .iconset bundle.

import AppKit
import CoreGraphics

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

let outputDir = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(size px: Int) -> NSImage {
    let size = CGFloat(px)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    // 1. Squircle background with gradient.
    let cornerRadius = size * 0.225
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1.0),
            CGColor(red: 0.10, green: 0.25, blue: 0.65, alpha: 1.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end:   CGPoint(x: size, y: 0),
        options: []
    )

    // 2. Soft inner highlight to give "Liquid Glass" sheen.
    let highlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.35),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        highlight,
        startCenter: CGPoint(x: size * 0.30, y: size * 0.85),
        startRadius: 0,
        endCenter:   CGPoint(x: size * 0.30, y: size * 0.85),
        endRadius:   size * 0.55,
        options: []
    )

    // 3. SF-symbol "computermouse.fill" rendered white in the center.
    if let symbol = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil) {
        let baseConfig = NSImage.SymbolConfiguration(pointSize: size * 0.55, weight: .semibold)
        let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
        let configured = symbol
            .withSymbolConfiguration(baseConfig.applying(whiteConfig)) ?? symbol
        let glyphSize = configured.size
        let glyphRect = NSRect(
            x: (size - glyphSize.width) / 2,
            y: (size - glyphSize.height) / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )

        // Drop-shadow under the glyph.
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -size * 0.015),
            blur: size * 0.05,
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        )
        configured.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try png.write(to: url)
}

for entry in sizes {
    let img = renderIcon(size: entry.px)
    let url = outputDir.appendingPathComponent(entry.name)
    try writePNG(img, to: url)
    print("wrote \(entry.name) (\(entry.px)px)")
}

print("Run: iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns")
