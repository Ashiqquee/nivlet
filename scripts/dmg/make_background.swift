// Draws the disk-image window background: a caption and an arrow from Nivlet to Applications.
// Usage, from the repository root: xcrun swift scripts/dmg/make_background.swift [light|dark] [output.tiff]
// The layout matches the icon positions in scripts/distribute.py (660 × 460 points).
import AppKit

let arguments = CommandLine.arguments
let dark = arguments.count > 1 && arguments[1] == "dark"
let output = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : "scripts/dmg/background.tiff")
let size = CGSize(width: 660, height: 460)

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let top = dark ? NSColor(srgbRed: 0.13, green: 0.135, blue: 0.15, alpha: 1) : NSColor(srgbRed: 0.98, green: 0.98, blue: 0.985, alpha: 1)
    let bottom = dark ? NSColor(srgbRed: 0.085, green: 0.09, blue: 0.1, alpha: 1) : NSColor(srgbRed: 0.925, green: 0.925, blue: 0.94, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: CGRect(origin: .zero, size: size), angle: -90)

    // AppKit's origin is bottom-left; Finder positions are measured from the top.
    let caption = NSAttributedString(string: "Drag Nivlet into Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: dark ? NSColor(white: 1, alpha: 0.88) : NSColor(white: 0.11, alpha: 1),
    ])
    let captionSize = caption.size()
    caption.draw(at: CGPoint(x: (size.width - captionSize.width) / 2, y: size.height - 76))

    let arrowY = size.height - 190
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 268, y: arrowY))
    arrow.line(to: CGPoint(x: 388, y: arrowY))
    arrow.move(to: CGPoint(x: 374, y: arrowY + 12))
    arrow.line(to: CGPoint(x: 390, y: arrowY))
    arrow.line(to: CGPoint(x: 374, y: arrowY - 12))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    (dark ? NSColor(white: 1, alpha: 0.45) : NSColor(white: 0, alpha: 0.35)).setStroke()
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: size)
image.addRepresentation(render(scale: 1))
image.addRepresentation(render(scale: 2))
try image.tiffRepresentation(using: .lzw, factor: 0)!.write(to: output)
print("Wrote \(output.path)")
