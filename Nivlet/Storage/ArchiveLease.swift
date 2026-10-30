import Foundation
import Darwin

/// A small durable pin, containing digests only. Interrupted operations are
/// reconciled at startup before any cleanup; unreadable pins stop cleanup.
nonisolated struct ArchiveLease: Codable {
    var ownerPID: Int32 = getpid()
    let id: UUID
    var digests: Set<String>
    var protectsAllAssets: Bool
}

nonisolated enum ArchiveLeases {
    static func directory(root: URL) -> URL { root.appending(path: "archive-operations") }
    static func write(_ lease: ArchiveLease, root: URL) throws {
        let folder = directory(root: root); try ArchiveDisk.directory(root); try ArchiveDisk.directory(folder)
        try JSONEncoder().encode(lease).write(to: folder.appending(path: "\(lease.id.uuidString).json"), options: .atomic)
        try ArchiveDisk.syncDirectory(folder)
    }
    static func readAll(root: URL) throws -> [ArchiveLease] {
        let folder = directory(root: root)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        try ArchiveDisk.directory(folder)
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).map { url in
            let (file, size) = try ArchiveDisk.reader(url); defer { try? file.close() }
            guard size <= 2_000_000 else { throw PocketArchiveError.invalid }
            let lease = try JSONDecoder().decode(ArchiveLease.self, from: ArchiveDisk.exact(file, Int(size)))
            guard lease.ownerPID > 0, url.lastPathComponent == "\(lease.id.uuidString).json", lease.digests.allSatisfy(ArchiveDisk.isDigest) else { throw PocketArchiveError.invalid }
            return lease
        }
    }
    static func ownerIsRunning(_ lease: ArchiveLease) -> Bool {
        kill(lease.ownerPID, 0) == 0 || errno != ESRCH
    }
    static func remove(_ id: UUID, root: URL) throws {
        let folder = directory(root: root); try ArchiveDisk.directory(folder)
        let url = folder.appending(path: "\(id.uuidString).json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try ArchiveDisk.syncDirectory(folder)
    }
}
