import CryptoKit
import Darwin
import Foundation

/// Bounded filesystem operations shared by archive validation and cleanup.
/// Archive-controlled names never become destination paths.
nonisolated enum ArchiveDisk {
    static let magic = Data("NIVLET01".utf8)
    static let chunk = 1 << 20

    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func directory(_ url: URL) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) { try manager.createDirectory(at: url, withIntermediateDirectories: true) }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else { throw PocketArchiveError.invalid }
    }
    static func reader(_ url: URL) throws -> (FileHandle, UInt64) {
        guard url.isFileURL, !url.path.contains("\0") else { throw PocketArchiveError.invalid }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw PocketArchiveError.invalid }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0 else {
            try? file.close(); throw PocketArchiveError.invalid
        }
        return (file, UInt64(info.st_size))
    }
    static func writer(_ url: URL) throws -> FileHandle {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }
    static func exact(_ file: FileHandle, _ count: Int) throws -> Data {
        var data = Data()
        while data.count < count {
            try Task.checkCancellation()
            guard let part = try file.read(upToCount: count - data.count), !part.isEmpty else { throw PocketArchiveError.invalid }
            data.append(part)
        }
        return data
    }
    static func number(_ value: UInt64) -> Data {
        var big = value.bigEndian
        return withUnsafeBytes(of: &big) { Data($0) }
    }
    static func readNumber(_ file: FileHandle) throws -> UInt64 {
        try exact(file, 8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
    @discardableResult
    static func copy(_ reader: FileHandle, count: UInt64, to writer: FileHandle?, digest expected: String? = nil) throws -> String {
        var left = count; var hash = SHA256()
        while left > 0 {
            try Task.checkCancellation()
            let data = try exact(reader, Int(min(left, UInt64(chunk))))
            hash.update(data: data); try writer?.write(contentsOf: data); left -= UInt64(data.count)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        if let expected, digest != expected { throw PocketArchiveError.corruptAsset }
        return digest
    }
    static func verify(_ url: URL, asset: PocketArchiveManifest.Asset) throws {
        let (file, size) = try reader(url); defer { try? file.close() }
        guard size == asset.byteCount else { throw PocketArchiveError.corruptAsset }
        try copy(file, count: size, to: nil, digest: asset.digest)
    }
    static func checkSpace(at url: URL, bytes: UInt64) throws {
        let values = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        if let free = (values[.systemFreeSize] as? NSNumber)?.uint64Value, free < bytes { throw PocketArchiveError.noSpace }
    }
    static func forbidInternal(_ url: URL, root: URL) throws {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        let own = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolved != own, !resolved.hasPrefix(own + "/") else { throw PocketArchiveError.unsafeLocation }
    }
    static func syncDirectory(_ url: URL) throws {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw PocketArchiveError.invalid }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
