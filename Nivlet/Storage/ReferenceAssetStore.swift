import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Owns original bytes. All copying/hashing is serial and off the UI executor.
/// A placed but unreferenced asset is retained for safe retry; no orphan cleanup
/// races the metadata store, pending saves or in-session deletion Undo.
actor ReferenceAssetStore {
    let root: URL
    let limits: ReferenceImportLimits
    enum FailurePoint: Sendable { case afterStaging, afterPlacement }
    private var failure: FailurePoint?

    init(root: URL, limits: ReferenceImportLimits = .init()) { self.root = root; self.limits = limits }
    func failNextImportForTesting(at point: FailurePoint) { failure = point }

    func importSource(_ source: ReferenceImportSource, confirmed: Bool = false) throws -> ReferenceItem {
        let manager = FileManager.default
        let staging = root.appending(path: "staging/\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        let staged = staging.appending(path: "original")
        let writer: FileHandle
        guard manager.createFile(atPath: staged.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        writer = try FileHandle(forWritingTo: staged)
        defer { try? writer.close() }
        var hasher = SHA256()
        var total: Int64 = 0
        func append(_ bytes: Data) throws {
            try Task.checkCancellation()
            total += Int64(bytes.count)
            try limits.validate(total, confirmed: confirmed)
            try writer.write(contentsOf: bytes)
            hasher.update(data: bytes)
        }
        switch source {
        case .unavailable: throw LibraryStoreError.unreadableFile
        case .file(let url):
            guard url.isFileURL, !url.path.contains("\0") else { throw LibraryStoreError.invalidFile }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            // O_NOFOLLOW plus fstat rejects symlinks, directories and named pipes
            // without trusting a path check followed by a second, racy open.
            let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
            guard descriptor >= 0 else {
                if errno == ELOOP { throw LibraryStoreError.invalidFile }
                throw LibraryStoreError.unreadableFile
            }
            let reader = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? reader.close() }
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw LibraryStoreError.invalidFile }
            try limits.validate(info.st_size, confirmed: confirmed)
            while let bytes = try reader.read(upToCount: 1 << 20), !bytes.isEmpty { try append(bytes) }
        case .image(let bytes, _):
            try limits.validate(Int64(bytes.count), confirmed: confirmed)
            for start in stride(from: 0, to: bytes.count, by: 1 << 20) {
                try append(bytes.subdata(in: start..<min(bytes.count, start + (1 << 20))))
            }
        }
        try Task.checkCancellation()
        try writer.synchronize()
        try writer.close()
        let isImage = Self.isImageFile(staged)
        if failure == .afterStaging { failure = nil; throw LibraryStoreError.injectedFailure }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let folder = root.appending(path: "assets/\(digest)")
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: "original")
        if manager.fileExists(atPath: destination.path) {
            guard try destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true,
                  try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                  try FileHandoff.sha256(of: destination) == digest else { throw LibraryStoreError.invalidFile }
        } else {
            try manager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: staged.path)
            try manager.moveItem(at: staged, to: destination)
        }
        try manager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: destination.path)
        if failure == .afterPlacement { failure = nil; throw LibraryStoreError.injectedFailure }
        return ReferenceItem(id: UUID(), label: URL(fileURLWithPath: source.name).deletingPathExtension().lastPathComponent,
                             note: "", displayName: source.name, originalURL: destination,
                             isImage: isImage,
                             byteCount: total)
    }

    nonisolated static func isImageFile(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let identifier = CGImageSourceGetType(source), let type = UTType(identifier as String), type.conforms(to: .image),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else { return false }
        return width > 0 && height > 0
    }
}
