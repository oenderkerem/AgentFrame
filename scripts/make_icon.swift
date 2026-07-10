#!/usr/bin/env swift
// Generates Resources/AppIcon.icns from scratch using CoreGraphics.
// Design: four L-shaped corner brackets on a dark background,
//         colored with a clockwise orange → yellow → green → teal gradient.
// Usage:  swift scripts/make_icon.swift   (from project root)

import AppKit

// MARK: - Palette

let bgColor = CGColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)  // #1C1C1E
let colTL   = CGColor(srgbRed: 1.000, green: 0.624, blue: 0.039, alpha: 1)  // #FF9F0A  orange
let colTR   = CGColor(srgbRed: 1.000, green: 0.839, blue: 0.039, alpha: 1)  // #FFD60A  yellow
let colBR   = CGColor(srgbRed: 0.188, green: 0.820, blue: 0.345, alpha: 1)  // #30D158  green
let colBL   = CGColor(srgbRed: 0.188, green: 0.808, blue: 0.753, alpha: 1)  // #30CEC0  teal

// MARK: - Drawing

func drawL(ctx: CGContext,
           cx: CGFloat, cy: CGFloat,
           hDir: CGFloat, vDir: CGFloat,
           arm: CGFloat, thick: CGFloat,
           color: CGColor) {
    let hRect = CGRect(
        x:      hDir > 0 ? cx : cx - arm,
        y:      vDir > 0 ? cy : cy - thick,
        width:  arm, height: thick)
    let vRect = CGRect(
        x:      hDir > 0 ? cx : cx - thick,
        y:      vDir > 0 ? cy : cy - arm,
        width:  thick, height: arm)
    ctx.setFillColor(color)
    ctx.fill([hRect, vRect])
}

func renderIcon(size: Int) -> CGImage {
    let s  = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Background (rounded square, matches macOS icon shape)
    let r      = s * 0.225
    let bgPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
        cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(bgColor)
    ctx.fillPath()

    // Bracket dimensions
    let margin = s * 0.165
    let thick  = s * 0.083
    let arm    = s * 0.255

    // Clip to bg so brackets never bleed outside the rounded corners
    ctx.addPath(bgPath)
    ctx.clip()

    // TL: corner at (margin, s−margin) → right & down in CG coords
    drawL(ctx: ctx, cx: margin,   cy: s-margin, hDir:  1, vDir: -1, arm: arm, thick: thick, color: colTL)
    // TR: corner at (s−margin, s−margin) → left & down
    drawL(ctx: ctx, cx: s-margin, cy: s-margin, hDir: -1, vDir: -1, arm: arm, thick: thick, color: colTR)
    // BR: corner at (s−margin, margin) → left & up
    drawL(ctx: ctx, cx: s-margin, cy: margin,   hDir: -1, vDir:  1, arm: arm, thick: thick, color: colBR)
    // BL: corner at (margin, margin) → right & up
    drawL(ctx: ctx, cx: margin,   cy: margin,   hDir:  1, vDir:  1, arm: arm, thick: thick, color: colBL)

    return ctx.makeImage()!
}

func png(_ img: CGImage) -> Data {
    NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
}

// MARK: - Export

let fm      = FileManager.default
let iconset = "AppIcon.iconset"
let output  = "Resources/AppIcon.icns"

try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png",1024),
]

for (name, size) in specs {
    try! png(renderIcon(size: size))
        .write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    print("  \(iconset)/\(name)")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", output]
try! iconutil.run()
iconutil.waitUntilExit()

try? fm.removeItem(atPath: iconset)

if iconutil.terminationStatus == 0 {
    print("✓ \(output)")
} else {
    print("✗ iconutil fehlgeschlagen")
    exit(1)
}
