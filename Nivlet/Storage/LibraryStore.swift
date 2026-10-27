import CryptoKit
import Foundation
import SQLite3
import UniformTypeIdentifiers

nonisolated enum LibraryStoreError: LocalizedError, Sendable {
    case database(String)
    case newerVersion
    case invalidFile
    case fileTooLarge
    case injectedFailure

    var errorDescription: String? {
        switch self {
        case .database: "Couldn't save the library. Your changes are still here. Try again."
        case .newerVersion: "This library was saved by a newer version of Nivlet. Open it with that version."
        case .invalidFile: "Choose a regular file. Folders and symbolic links aren't supported."
        case .fileTooLarge: "Choose a file smaller than 100 MB for this build."
        case .injectedFailure: "The test save failed. Your changes are still here. Try again."
        }
    }
}

/// One serial boundary for SQLite and staged file imports. Its synchronous work
/// runs on the actor executor, away from the main actor and pointer interactions.
actor LibraryStore {
    let root: URL
    private var newestRevision: UInt64 = 0
    private var shouldFailNextCommit = false

    init(root: URL) { self.root = root }

    func failNextCommitForTesting() { shouldFailNextCommit = true }

    func load() throws -> LibrarySnapshot {
        try withDatabase { db in
            var snapshot = LibrarySnapshot.empty
            let pockets = try rows(db, "SELECT id, name FROM pockets LIMIT 1")
            guard let pocket = pockets.first, let id = UUID(uuidString: pocket[0]) else { return snapshot }
            snapshot.pocketID = id; snapshot.pocketName = pocket[1]
            for item in try rows(db, "SELECT id, kind, label, body, favorite, uses_fields FROM text_items ORDER BY position") {
                guard let itemID = UUID(uuidString: item[0]) else { throw LibraryStoreError.database("invalid identity") }
                if item[1] == "instruction" {
                    snapshot.instructions.append(Instruction(id: itemID, label: item[2], body: item[3], isFavorite: item[4] == "1"))
                } else {
                    snapshot.prompts.append(SavedPrompt(id: itemID, label: item[2], source: item[3], isFavorite: item[4] == "1", usesFields: item[5] == "1"))
                }
            }
            snapshot.note = try rows(db, "SELECT body FROM scratchpads LIMIT 1").first?.first ?? ""
            for item in try rows(db, "SELECT id, label, note, display_name, asset, is_image FROM reference_items ORDER BY position") {
                guard let itemID = UUID(uuidString: item[0]), Self.isDigest(item[4]) else { throw LibraryStoreError.database("invalid asset") }
                snapshot.references.append(ReferenceItem(id: itemID, label: item[1], note: item[2], displayName: item[3],
                    originalURL: root.appending(path: "assets/\(item[4])/original"), isImage: item[5] == "1"))
            }
            return snapshot
        }
    }

    @discardableResult
    func save(_ snapshot: LibrarySnapshot, revision: UInt64) throws -> Bool {
        guard revision >= newestRevision else { return false }
        // Even a failed newer write prevents a late older snapshot from winning.
        newestRevision = revision
        try withDatabase { db in
            try execute(db, "BEGIN IMMEDIATE")
            do {
                try execute(db, "DELETE FROM text_items; DELETE FROM reference_items; DELETE FROM scratchpads; DELETE FROM pockets;")
                let pocketID = snapshot.pocketID.uuidString
                try insert(db, "INSERT INTO pockets VALUES (?, ?)", [pocketID, snapshot.pocketName])
                for (position, item) in snapshot.instructions.enumerated() {
                    try insert(db, "INSERT INTO text_items VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        [item.id.uuidString, pocketID, "instruction", item.label, item.body, item.isFavorite ? "1" : "0", "\(position)", "0"])
                }
                for (position, item) in snapshot.prompts.enumerated() {
                    try insert(db, "INSERT INTO text_items VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        [item.id.uuidString, pocketID, "prompt", item.label, item.source, item.isFavorite ? "1" : "0", "\(position)", item.usesFields ? "1" : "0"])
                }
                try insert(db, "INSERT INTO scratchpads VALUES (?, ?)", [pocketID, snapshot.note])
                for (position, item) in snapshot.references.enumerated() {
                    let digest = item.originalURL.deletingLastPathComponent().lastPathComponent
                    guard Self.isDigest(digest) else { throw LibraryStoreError.invalidFile }
                    try insert(db, "INSERT INTO reference_items VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        [item.id.uuidString, pocketID, item.label, item.note, item.displayName, digest, item.isImage ? "1" : "0", "\(position)"])
                }
                if shouldFailNextCommit { shouldFailNextCommit = false; throw LibraryStoreError.injectedFailure }
                try execute(db, "COMMIT")
            } catch {
                try? execute(db, "ROLLBACK")
                throw error
            }
        }
        return true
    }

    /// Stage/copy/hash before metadata can reference the asset. Interrupted imports
    /// may leave an unreferenced immutable asset; cleanup never deletes it here.
    func importFile(_ source: URL) throws -> ReferenceItem {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let properties = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentTypeKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else { throw LibraryStoreError.invalidFile }
        guard (properties.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw LibraryStoreError.fileTooLarge }
        let manager = FileManager.default
        let staging = root.appending(path: "staging/\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        let staged = staging.appending(path: "original")
        try manager.copyItem(at: source, to: staged)
        guard (try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 100 * 1024 * 1024 else { throw LibraryStoreError.fileTooLarge }
        let handle = try FileHandle(forReadingFrom: staged)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1 << 20), !data.isEmpty { hasher.update(data: data) }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let folder = root.appending(path: "assets/\(digest)")
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: "original")
        if manager.fileExists(atPath: destination.path) {
            guard try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                  try FileHandoff.sha256(of: destination) == digest else { throw LibraryStoreError.invalidFile }
        } else {
            try manager.moveItem(at: staged, to: destination)
            try manager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: destination.path)
        }
        return ReferenceItem(id: UUID(), label: source.deletingPathExtension().lastPathComponent, note: "",
            displayName: source.lastPathComponent, originalURL: destination,
            isImage: properties.contentType?.conforms(to: .image) == true)
    }

    private static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private func withDatabase<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(root.appending(path: "library.sqlite").path, &pointer,
                             SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw LibraryStoreError.database("open")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 3000)
        try execute(db, "PRAGMA foreign_keys = ON; PRAGMA synchronous = FULL;")
        let version = Int(try rows(db, "PRAGMA user_version").first?.first ?? "0") ?? 0
        guard version <= 2 else { throw LibraryStoreError.newerVersion }
        if version == 0 {
            try execute(db, """
                BEGIN IMMEDIATE;
                CREATE TABLE IF NOT EXISTS pockets (id TEXT PRIMARY KEY, name TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS text_items (
                    id TEXT PRIMARY KEY, pocket_id TEXT NOT NULL REFERENCES pockets(id),
                    kind TEXT NOT NULL CHECK(kind IN ('instruction','prompt')), label TEXT NOT NULL,
                    body TEXT NOT NULL, favorite INTEGER NOT NULL, position INTEGER NOT NULL, uses_fields INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS scratchpads (pocket_id TEXT PRIMARY KEY REFERENCES pockets(id), body TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS reference_items (
                    id TEXT PRIMARY KEY, pocket_id TEXT NOT NULL REFERENCES pockets(id), label TEXT NOT NULL,
                    note TEXT NOT NULL, display_name TEXT NOT NULL, asset TEXT NOT NULL,
                    is_image INTEGER NOT NULL, position INTEGER NOT NULL);
                PRAGMA user_version = 2;
                COMMIT;
                """)
        }
        if version == 1 {
            try snapshotBeforeMigration(db, version: version)
            try execute(db, """
                BEGIN IMMEDIATE;
                ALTER TABLE text_items ADD COLUMN uses_fields INTEGER NOT NULL DEFAULT 0;
                UPDATE text_items SET uses_fields = 1 WHERE kind = 'prompt' AND instr(body, '{{') > 0;
                PRAGMA user_version = 2;
                COMMIT;
                """)
        }
        return try work(db)
    }


    private func snapshotBeforeMigration(_ db: OpaquePointer, version: Int) throws {
        let snapshots = root.appending(path: "snapshots")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let url = snapshots.appending(path: "library-v\(version)-\(UUID().uuidString).sqlite")
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let backupDB = pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw LibraryStoreError.database("snapshot open")
        }
        defer { sqlite3_close(backupDB) }
        guard let backup = sqlite3_backup_init(backupDB, "main", db, "main") else { throw LibraryStoreError.database("snapshot init") }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else { throw LibraryStoreError.database("snapshot write") }
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw LibraryStoreError.database("execute") }
    }

    private func insert(_ db: OpaquePointer, _ sql: String, _ values: [String]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LibraryStoreError.database("prepare")
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let result = value.withCString { sqlite3_bind_text(statement, Int32(index + 1), $0, Int32(value.utf8.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard result == SQLITE_OK else { throw LibraryStoreError.database("bind") }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw LibraryStoreError.database("insert") }
    }

    private func rows(_ db: OpaquePointer, _ sql: String) throws -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LibraryStoreError.database("prepare")
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw LibraryStoreError.database("read") }
            result.append((0..<sqlite3_column_count(statement)).map { column in
                guard let bytes = sqlite3_column_text(statement, column) else { return "" }
                return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(statement, column))), as: UTF8.self)
            })
        }
    }
}
