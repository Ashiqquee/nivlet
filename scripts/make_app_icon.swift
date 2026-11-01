// Builds Nivlet/Assets.xcassets/AppIcon.appiconset from the nivlet-v1 favicon master.
// Usage, from the repository root: xcrun swift scripts/make_app_icon.swift
// Follows Apple's macOS icon grid: an 824-point rounded square centred on a 1024 canvas.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let master = root.appendingPathComponent("output/brand/nivlet-v1/favicon-master.png")
let catalog = root.appendingPathComponent("Nivlet/Assets.xcassets")
let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")

guard let source = NSImage(contentsOf: master)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Missing \(master.path)")
}

func render(pixels: Int) -> Data {
    let scale = CGFloat(pixels) / 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    // Soft drop shadow from Apple's macOS icon template.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(shape)
    context.setFillColor(CGColor(srgbRed: 0.094, green: 0.098, blue: 0.11, alpha: 1))
    context.fillPath()
    context.restoreGState()
    // The master is a full-bleed charcoal square with a white N; inset it slightly so the N keeps breathing room.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(source, in: tile.insetBy(dx: 36, dy: 36))
    context.restoreGState()
    // Hairline edge so the dark tile stays defined on dark backgrounds.
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 1, dy: 1), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.12))
    context.setLineWidth(2)
    context.strokePath()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalog.appendingPathComponent("Contents.json"))
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon images to \(iconSet.path)")

// Menu-bar glyph: the transparent mark, cropped to its ink and drawn black as a template image
// so macOS tints it for light, dark and highlighted menu bars.
let markURL = root.appendingPathComponent("output/brand/nivlet-v1/nivlet-mark-master.png")
guard let mark = NSImage(contentsOf: markURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let markData = mark.dataProvider?.data, let bytes = CFDataGetBytePtr(markData) else {
    fatalError("Missing \(markURL.path)")
}
var ink = CGRect.null
let alphaOffset = mark.alphaInfo == .premultipliedFirst || mark.alphaInfo == .first ? 0 : 3
for y in 0..<mark.height {
    for x in 0..<mark.width where bytes[y * mark.bytesPerRow + x * mark.bitsPerPixel / 8 + alphaOffset] > 24 {
        ink = ink.union(CGRect(x: x, y: mark.height - y - 1, width: 1, height: 1))
    }
}
let glyph = mark.cropping(to: CGRect(x: ink.minX, y: CGFloat(mark.height) - ink.maxY, width: ink.width, height: ink.height))!

func menuBarIcon(scale: Int) -> Data {
    let side = 18 * scale
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let height = CGFloat(15 * scale), width = height * ink.width / ink.height
    let frame = CGRect(x: (CGFloat(side) - width) / 2, y: (CGFloat(side) - height) / 2, width: width, height: height)
    context.clip(to: frame, mask: glyph)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(frame)
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

let menuSet = catalog.appendingPathComponent("MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: menuSet, withIntermediateDirectories: true)
try menuBarIcon(scale: 1).write(to: menuSet.appendingPathComponent("menubar.png"))
try menuBarIcon(scale: 2).write(to: menuSet.appendingPathComponent("menubar@2x.png"))
let menuContents: [String: Any] = [
    "images": [["idiom": "mac", "scale": "1x", "filename": "menubar.png"], ["idiom": "mac", "scale": "2x", "filename": "menubar@2x.png"]],
    "info": ["author": "xcode", "version": 1],
    "properties": ["template-rendering-intent": "template"],
]
try JSONSerialization.data(withJSONObject: menuContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: menuSet.appendingPathComponent("Contents.json"))
print("Wrote menu-bar template icon to \(menuSet.path)")
