import AppKit
import Foundation

guard CommandLine.arguments.count == 3,
      let size = Int(CommandLine.arguments[1]) else {
    fputs("Usage: render_icon.swift <size> <output-path>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[2]
let canvasSize = NSSize(width: size, height: size)
let image = NSImage(size: canvasSize)

image.lockFocus()

let bounds = NSRect(origin: .zero, size: canvasSize)
NSColor(calibratedRed: 0.97, green: 0.71, blue: 0.28, alpha: 1.0).setFill()
NSBezierPath(roundedRect: bounds, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22).fill()

let inset = CGFloat(size) * 0.12
let shellRect = bounds.insetBy(dx: inset, dy: inset * 1.1)
NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.20, alpha: 1.0).setFill()
NSBezierPath(roundedRect: shellRect, xRadius: CGFloat(size) * 0.12, yRadius: CGFloat(size) * 0.12).fill()

let labelInsetX = CGFloat(size) * 0.1
let labelInsetY = CGFloat(size) * 0.18
let labelRect = shellRect.insetBy(dx: labelInsetX, dy: labelInsetY)
NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.88, alpha: 1.0).setFill()
NSBezierPath(roundedRect: labelRect, xRadius: CGFloat(size) * 0.07, yRadius: CGFloat(size) * 0.07).fill()

let reelRadius = CGFloat(size) * 0.11
let reelY = shellRect.midY + CGFloat(size) * 0.01
let leftReelCenter = NSPoint(x: shellRect.minX + CGFloat(size) * 0.25, y: reelY)
let rightReelCenter = NSPoint(x: shellRect.maxX - CGFloat(size) * 0.25, y: reelY)

func fillCircle(center: NSPoint, radius: CGFloat, color: NSColor) {
    color.setFill()
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    NSBezierPath(ovalIn: rect).fill()
}

fillCircle(center: leftReelCenter, radius: reelRadius, color: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.28, alpha: 1.0))
fillCircle(center: rightReelCenter, radius: reelRadius, color: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.28, alpha: 1.0))
fillCircle(center: leftReelCenter, radius: reelRadius * 0.34, color: NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.37, alpha: 1.0))
fillCircle(center: rightReelCenter, radius: reelRadius * 0.34, color: NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.37, alpha: 1.0))

let windowWidth = CGFloat(size) * 0.18
let windowHeight = CGFloat(size) * 0.11
let windowRect = NSRect(
    x: shellRect.midX - windowWidth / 2,
    y: shellRect.midY - windowHeight / 2 - CGFloat(size) * 0.04,
    width: windowWidth,
    height: windowHeight
)
NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.87, alpha: 1.0).setFill()
NSBezierPath(roundedRect: windowRect, xRadius: CGFloat(size) * 0.03, yRadius: CGFloat(size) * 0.03).fill()

let tapePath = NSBezierPath()
tapePath.move(to: NSPoint(x: leftReelCenter.x + reelRadius * 0.8, y: leftReelCenter.y - reelRadius * 0.2))
tapePath.line(to: NSPoint(x: windowRect.minX, y: windowRect.midY))
tapePath.line(to: NSPoint(x: windowRect.maxX, y: windowRect.midY))
tapePath.line(to: NSPoint(x: rightReelCenter.x - reelRadius * 0.8, y: rightReelCenter.y - reelRadius * 0.2))
NSColor(calibratedWhite: 0.2, alpha: 0.55).setStroke()
tapePath.lineWidth = max(CGFloat(size) * 0.016, 1.0)
tapePath.stroke()

let bottomSlot = NSRect(
    x: shellRect.minX + CGFloat(size) * 0.18,
    y: shellRect.minY + CGFloat(size) * 0.12,
    width: shellRect.width - CGFloat(size) * 0.36,
    height: CGFloat(size) * 0.08
)
NSColor(calibratedWhite: 0.11, alpha: 1.0).setFill()
NSBezierPath(roundedRect: bottomSlot, xRadius: CGFloat(size) * 0.025, yRadius: CGFloat(size) * 0.025).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Failed to write icon: \(error)\n", stderr)
    exit(1)
}
