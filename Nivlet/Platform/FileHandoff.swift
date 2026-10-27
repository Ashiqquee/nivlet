import CryptoKit
import Foundation

/// Produces disposable export copies for dragging or Reveal in Finder, so the
/// receiving app never touches Nivlet's original bytes.
nonisolated struct FileHandoff: Sendable {
    let exportRoot: URL

    static let standard = FileHandoff(
        exportRoot: URL.cachesDirectory.appending(path: "transfer-exports", directoryHint: .isDirectory)
    )

    /// Copies `source` into a fresh export folder under its display name and makes
    /// the copy read-only. The source is never moved or modified.
    func exportCopy(of source: URL, displayName: String) throws -> URL {
        let folder = exportRoot.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: Self.safeFileName(displayName), directoryHint: .notDirectory)
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: destination.path(percentEncoded: false))
        return destination
    }

    /// Removes export folders older than `age`. Receiving apps may read a dropped
    /// file asynchronously, so exports are never deleted as soon as a drag ends.
    func removeExports(olderThan age: TimeInterval, now: Date = .now) {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(
            at: exportRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for folder in folders {
            let created = (try? folder.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? now
            guard now.timeIntervalSince(created) > age else { continue }
            makeWritable(folder)
            try? manager.removeItem(at: folder)
        }
    }

    /// Hex SHA-256 of a file, read in chunks so large files are not loaded at once.
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Keeps a display name to a single path component.
    static func safeFileName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." { return "Reference" }
        return cleaned
    }

    private func makeWritable(_ folder: URL) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? manager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path(percentEncoded: false))
        }
    }
}
