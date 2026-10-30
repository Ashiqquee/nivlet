// Packs existing PNG exports into an ICO container; does not redraw the artwork.
// Run from this directory: swift package-favicon.swift
import Foundation
import ImageIO

let sizes = [16, 32, 48]
let payloads = try sizes.map { size -> Data in
    let url = URL(fileURLWithPath: "favicon-\(size).png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == size, image.height == size else {
        fatalError("Invalid PNG dimensions: \(url.lastPathComponent)")
    }
    return try Data(contentsOf: url)
}
var container = Data()
func append16(_ value: UInt16) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { container.append(contentsOf: $0) }
}
func append32(_ value: UInt32) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { container.append(contentsOf: $0) }
}
append16(0)
append16(1)
append16(UInt16(sizes.count))
var offset = UInt32(6 + sizes.count * 16)
for (size, payload) in zip(sizes, payloads) {
    container.append(contentsOf: [UInt8(size), UInt8(size), 0, 0])
    append16(1)
    append16(24)
    append32(UInt32(payload.count))
    append32(offset)
    offset += UInt32(payload.count)
}
for payload in payloads { container.append(payload) }
let output = URL(fileURLWithPath: "favicon.ico")
try container.write(to: output, options: .atomic)
guard let decoded = CGImageSourceCreateWithURL(output as CFURL, nil),
      CGImageSourceGetCount(decoded) == sizes.count else {
    fatalError("ICO failed to decode")
}
var decodedSizes: [Int] = []
for index in sizes.indices {
    guard let image = CGImageSourceCreateImageAtIndex(decoded, index, nil),
          image.width == image.height else {
        fatalError("ICO frame \(index) failed to decode")
    }
    decodedSizes.append(image.width)
}
// ImageIO may return ICO frames in descending size order.
guard decodedSizes.sorted() == sizes else { fatalError("ICO sizes differ") }
print("favicon.ico: verified 16, 32 and 48 px frames with ImageIO")
