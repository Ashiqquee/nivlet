import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ReferencePreviewContent: Sendable {
    case image(Data), text(String, truncated: Bool), unavailable
}

nonisolated enum ReferencePreviewLoader {
    /// Static, bounded previews only: first image/frame or PDF page, plain UTF-8
    /// text otherwise. No WebView, Quick Look plugin, scripts, URLs or OCR.
    @concurrent static func load(_ url: URL, image: Bool, maxPixels: Int = 1200, displayName: String = "") async -> ReferencePreviewContent {
        guard !Task.isCancelled else { return .unavailable }
        let pixels = min(1600, max(1, maxPixels))
        if image {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double,
                  width > 0, height > 0, width * height <= 64_000_000,
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixels,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return .unavailable }
            return png(thumbnail)
        }
        if URL(fileURLWithPath: displayName).pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL), !document.isEncrypted,
                  let page = document.page(at: 1) else { return .unavailable }
            let bounds = page.getBoxRect(.mediaBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { return .unavailable }
            let scale = CGFloat(pixels) / max(bounds.width, bounds.height)
            guard scale.isFinite else { return .unavailable }
            let width = max(1, Int(bounds.width * scale)), height = max(1, Int(bounds.height * scale))
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .unavailable }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.concatenate(page.getDrawingTransform(.mediaBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            return context.makeImage().map(png) ?? .unavailable
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unavailable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 32 * 1024 + 1), !data.contains(0) else { return .unavailable }
        let truncated = data.count > 32 * 1024
        var prefix = data.prefix(32 * 1024)
        // A bounded read may split a UTF-8 scalar; trim at most its trailing bytes.
        for _ in 0..<4 {
            if let text = String(data: prefix, encoding: .utf8) { return .text(text, truncated: truncated) }
            if !truncated || prefix.isEmpty { break }
            prefix = prefix.dropLast()
        }
        return .unavailable
    }

    private static func png(_ image: CGImage) -> ReferencePreviewContent {
        guard !Task.isCancelled else { return .unavailable }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return .unavailable }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return .unavailable }
        return .image(data as Data)
    }
}
