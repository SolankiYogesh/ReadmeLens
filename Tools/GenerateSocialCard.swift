#!/usr/bin/env swift
//
// Renders the repository's social preview card (1280×640).
//
// This is the image GitHub, Slack, X and search result cards show when the
// project is linked, so it carries the name and what the thing actually is
// rather than leaving a generic placeholder.
//
//   swift Tools/GenerateSocialCard.swift docs/social-card.png
//
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = CGSize(width: 1280, height: 640)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// GitHub Dark, matching the app's default theme.
let canvas = rgb(0x0D1117)
let canvasTop = rgb(0x161B22)
let accent = rgb(0x4493F8)
let bright = rgb(0xE6EDF3)
let muted = rgb(0x8B949E)
let border = rgb(0x30363D)

let image = NSImage(size: NSSize(width: size.width, height: size.height))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// Background gradient
let space = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: space,
    colors: [canvasTop.cgColor, canvas.cgColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// A hairline accent along the top, so the card reads as deliberate.
ctx.setFillColor(accent.cgColor)
ctx.fill(CGRect(x: 0, y: size.height - 6, width: size.width, height: 6))

func draw(_ text: String, x: CGFloat, y: CGFloat, size fontSize: CGFloat,
          weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
    ]
    NSAttributedString(string: text, attributes: attributes)
        .draw(at: NSPoint(x: x, y: y))
}

// Laid out from the bottom up, since AppKit's origin is bottom-left. The
// bands are spaced explicitly so nothing collides as text lengths change.
let left: CGFloat = 96
let iconTop: CGFloat = 560
let iconSize: CGFloat = 150
let titleBaseline: CGFloat = 300
let taglineOne: CGFloat = 238
let taglineTwo: CGFloat = 190
let chipY: CGFloat = 84

let iconPath = "Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png"
if let icon = NSImage(contentsOfFile: iconPath) {
    icon.draw(in: NSRect(x: left, y: iconTop - iconSize, width: iconSize, height: iconSize))
}

draw("ReadmeLens", x: left, y: titleBaseline, size: 78, weight: .bold, color: bright)
draw("A fast, native macOS Markdown viewer", x: left, y: taglineOne,
     size: 32, weight: .regular, color: muted)
draw("Read READMEs the way GitHub renders them", x: left, y: taglineTwo,
     size: 32, weight: .regular, color: muted)

// Feature chips
let chips = ["9 themes", "Syntax highlighting", "Quick Look", "Live reload", "Open source"]
var chipX = left
for chip in chips {
    let font = NSFont.systemFont(ofSize: 22, weight: .medium)
    let width = (chip as NSString)
        .size(withAttributes: [.font: font]).width + 34
    let rect = CGRect(x: chipX, y: chipY, width: width, height: 46)
    let path = CGPath(roundedRect: rect, cornerWidth: 23, cornerHeight: 23, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(rgb(0x161B22).cgColor)
    ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(border.cgColor)
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    draw(chip, x: chipX + 17, y: chipY + 11, size: 22, weight: .medium, color: bright)
    chipX += width + 14
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { fatalError("could not encode") }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "social-card.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(size.width))×\(Int(size.height)))")
