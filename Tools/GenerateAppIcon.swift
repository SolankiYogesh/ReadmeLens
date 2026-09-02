#!/usr/bin/env swift
//
// Renders ReadmeLens's app icon at every size the asset catalog needs.
//
// The icon is generated rather than checked in as opaque PNGs so it stays
// editable: change a colour or a proportion here and re-run.
//
//   swift Tools/GenerateAppIcon.swift <output-directory>
//
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Everything is laid out against a 1024pt design grid and scaled down, so the
// proportions hold at 16pt as well as 1024pt.
let grid: CGFloat = 1024

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red:   CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue:  CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// GitHub Dark, so the icon and the default theme agree.
let tileTop    = rgb(0x1B2129)
let tileBottom = rgb(0x0D1117)
let tileEdge   = rgb(0x30363D)
let textBright = rgb(0xE6EDF3)
let textMuted  = rgb(0x6E7681)
let accent     = rgb(0x4493F8)

func renderIcon(pixels: Int) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Flip to a top-left origin so the layout below reads like a design tool.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: 1, y: -1)
    let s = CGFloat(pixels) / grid
    ctx.scaleBy(x: s, y: s)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // --- rounded tile, inset to leave macOS's customary margin -------------
    let inset: CGFloat = 92
    let tile = CGRect(x: inset, y: inset, width: grid - inset * 2, height: grid - inset * 2)
    let radius: CGFloat = tile.width * 0.2237      // macOS squircle proportion
    let tilePath = CGPath(
        roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil
    )

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [tileTop, tileBottom] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: tile.midX, y: tile.minY),
        end:   CGPoint(x: tile.midX, y: tile.maxY),
        options: []
    )
    ctx.restoreGState()

    ctx.addPath(tilePath)
    ctx.setStrokeColor(tileEdge)
    ctx.setLineWidth(6)
    ctx.strokePath()

    // --- markdown text lines ----------------------------------------------
    func bar(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: CGColor) {
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    bar(x: 232, y: 268, w: 400, h: 56, color: textBright)   // the "heading"
    bar(x: 232, y: 372, w: 540, h: 44, color: textMuted)
    bar(x: 232, y: 454, w: 452, h: 44, color: textMuted)

    // --- the lens ----------------------------------------------------------
    let centre = CGPoint(x: 636, y: 662)
    let ringRadius: CGFloat = 156
    let ringWidth: CGFloat = 46

    // A dark knock-out slightly wider than the ring keeps the lens legible
    // where it passes near the text bars.
    ctx.setStrokeColor(tileBottom)
    ctx.setLineWidth(ringWidth + 26)
    ctx.addArc(center: centre, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // Handle, drawn before the ring so the ring caps it cleanly.
    let d = ringRadius * 0.7071
    ctx.setStrokeColor(accent)
    ctx.setLineWidth(ringWidth)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: centre.x + d, y: centre.y + d))
    ctx.addLine(to: CGPoint(x: centre.x + d + 96, y: centre.y + d + 96))
    ctx.strokePath()

    ctx.setStrokeColor(accent)
    ctx.setLineWidth(ringWidth)
    ctx.addArc(center: centre, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { fatalError("cannot create \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// asset-catalog filename → pixel size
let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),      ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),      ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),   ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),   ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),   ("icon_512x512@2x.png", 1024),
]

let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

var cache: [Int: CGImage] = [:]
for (name, px) in outputs {
    let image = cache[px] ?? renderIcon(pixels: px)
    cache[px] = image
    write(image, to: directory.appendingPathComponent(name))
    print("  \(name)  \(px)x\(px)")
}
print("rendered \(outputs.count) files")
