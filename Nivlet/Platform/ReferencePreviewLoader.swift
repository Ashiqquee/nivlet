import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ReferencePreviewContent: Sendable {
    case image(Data), text(String), unavailable
}

nonisolated enum ReferencePreviewLoader {
    /// Bounded decoding occurs off the UI actor. Hovering never reopens a file.
    @concurrent static func load(_ url: URL, image: Bool, maxPixels: Int = 1200) async -> ReferencePreviewContent {
        if image {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return .unavailable }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return .unavailable }
            CGImageDestinationAddImage(destination, thumbnail, nil)
            guard CGImageDestinationFinalize(destination) else { return .unavailable }
            return .image(data as Data)
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unavailable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 32 * 1024),
              let text = String(data: data, encoding: .utf8), !text.contains("\0") else { return .unavailable }
        return .text(text)
    }
}
