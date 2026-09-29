import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let preview = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let size = 1024

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// A quiet desktop-colored tile keeps the paper readable at Dock and Spotlight sizes.
let tile = rounded(NSRect(x: 32, y: 32, width: 960, height: 960), radius: 218)
NSGradient(starting: color(55, 83, 75), ending: color(30, 55, 49))!
    .draw(in: tile, angle: -55)

// Three edge tabs sit behind the note and give the icon its distinctive silhouette.
for (y, fill) in [
    (CGFloat(604), color(202, 218, 195)),
    (CGFloat(478), color(240, 195, 170)),
    (CGFloat(352), color(177, 208, 221))
] {
    fill.setFill()
    rounded(NSRect(x: 738, y: y, width: 136, height: 96), radius: 30).fill()
}

let paper = rounded(NSRect(x: 206, y: 222, width: 566, height: 614), radius: 56)
NSGraphicsContext.saveGraphicsState()
let paperShadow = NSShadow()
paperShadow.shadowColor = color(10, 31, 25, 0.33)
paperShadow.shadowBlurRadius = 34
paperShadow.shadowOffset = NSSize(width: 0, height: -18)
paperShadow.set()
NSGradient(starting: color(255, 245, 208), ending: color(244, 223, 169))!
    .draw(in: paper, angle: -90)
NSGraphicsContext.restoreGraphicsState()

color(255, 255, 255, 0.34).setStroke()
paper.lineWidth = 5
paper.stroke()

color(68, 84, 67, 0.48).setFill()
for (y, width) in [(CGFloat(653), CGFloat(316)), (CGFloat(557), CGFloat(255)), (CGFloat(461), CGFloat(296))] {
    rounded(NSRect(x: 284, y: y, width: width, height: 24), radius: 12).fill()
}

// The dark seam covers the paper's right edge: the note is tucked into the screen.
NSGraphicsContext.saveGraphicsState()
let seamShadow = NSShadow()
seamShadow.shadowColor = color(8, 26, 22, 0.27)
seamShadow.shadowBlurRadius = 15
seamShadow.shadowOffset = NSSize(width: -7, height: 0)
seamShadow.set()
color(36, 62, 54).setFill()
rounded(NSRect(x: 746, y: 194, width: 30, height: 642), radius: 15).fill()
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()

let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: temporary.appendingPathComponent(name))
        if points == 512, scale == 2, let preview {
            try rep.representation(using: .png, properties: [:])!.write(to: preview)
        }
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", temporary.path, "-o", destination.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("Icon creation failed") }
