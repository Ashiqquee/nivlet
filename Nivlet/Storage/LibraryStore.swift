import Foundation
import SQLite3

nonisolated enum LibraryStoreError: LocalizedError, Sendable {
    case database(String)
    case newerVersion
    case invalidFile
    case unreadableFile
    case confirmLargeFile
    case fileTooLarge
    case injectedFailure
    case diskFull

    var errorDescription: String? {
        switch self {
        case .database: "Couldn't save the library. Your changes are still here. Try again."
        case .newerVersion: "This library was saved by a newer version of Nivlet. Open it with that version."
        case .invalidFile: "Choose a regular file. Folders and symbolic links aren't supported."
        case .unreadableFile: "Couldn't read this file. Restore access or choose the file again."
        case .fileTooLarge: "Choose a file no larger than 2 GB."
        case .confirmLargeFile: "This file is over 500 MB. Confirm before importing a copy."
        case .injectedFailure: "The test save failed. Your changes are still here. Try again."
        case .diskFull: "Couldn't save because the disk is full. Free some space, then retry. Your changes are still here."
        }
    }
}

/// One serial boundary for SQLite and staged file imports. Its synchronous work
/// runs on the actor executor, away from the main actor and pointer interactions.
actor LibraryStore {
    let root: URL
    private let assets: ReferenceAssetStore
    private var newestRevision: UInt64 = 0
    enum CommitFailure: Sendable { case rollback, diskFull, interrupted }
    private var nextCommitFailure: CommitFailure?

    init(root: URL, assets: ReferenceAssetStore? = nil) {
        self.root = root; self.assets = assets ?? ReferenceAssetStore(root: root)
    }

    func failNextCommitForTesting(_ failure: CommitFailure = .rollback) { nextCommitFailure = failure }

    func load() throws -> LibrarySnapshot {
        try withDatabase { db in
            var snapshot = LibrarySnapshot.empty
            let pockets = try rows(db, "SELECT id, name FROM pockets")
            guard pockets.count <= 1 else { throw LibraryStoreError.database("multiple pockets") }
            guard let pocket = pockets.first else {
                try execute(db, "BEGIN IMMEDIATE")
                do {
                    try insert(db, "INSERT INTO pockets VALUES (?, ?)", [snapshot.pocketID.uuidString, snapshot.pocketName])
                    try insert(db, "INSERT INTO scratchpads VALUES (?, ?)", [snapshot.pocketID.uuidString, ""])
                    try execute(db, "COMMIT")
                } catch { try? execute(db, "ROLLBACK"); throw error }
                return snapshot
            }
            guard let id = UUID(uuidString: pocket[0]) else { throw LibraryStoreError.database("invalid pocket") }
            snapshot.pocketID = id; snapshot.pocketName = pocket[1]
            for item in try rows(db, "SELECT id, kind, label, body, favorite, uses_fields FROM text_items ORDER BY position") {
                guard let itemID = UUID(uuidString: item[0]) else { throw LibraryStoreError.database("invalid identity") }
                // Version 3 merged instructions into prompts; any kind loads as a prompt.
                snapshot.prompts.append(SavedPrompt(id: itemID, label: item[2], source: item[3], isFavorite: item[4] == "1",
                                                    usesFields: item[1] == "prompt" && item[5] == "1"))
            }
            snapshot.note = try rows(db, "SELECT body FROM scratchpads LIMIT 1").first?.first ?? ""
            for item in try rows(db, "SELECT id, label, note, display_name, asset, is_image FROM reference_items ORDER BY position") {
                guard let itemID = UUID(uuidString: item[0]), Self.isDigest(item[4]) else { throw LibraryStoreError.database("invalid asset") }
                let original = root.appending(path: "assets/\(item[4])/original")
                snapshot.references.append(ReferenceItem(id: itemID, label: item[1], note: item[2], displayName: item[3],
                    originalURL: original, isImage: ReferenceAssetStore.isImageFile(original)))
            }
            return snapshot
        }
    }

    /// A separate durable transaction records intent before replacing committed data.
    /// It is removed in the same transaction as the successful library write.
    func recoverableSnapshot() throws -> LibrarySnapshot? {
        try withDatabase { db in
            guard let json = try rows(db, "SELECT payload FROM pending_save WHERE id = 1").first?.first else { return nil }
            return try JSONDecoder().decode(LibrarySnapshot.self, from: Data(json.utf8))
        }
    }

    @discardableResult
    func save(_ snapshot: LibrarySnapshot, revision: UInt64) throws -> Bool {
        guard revision >= newestRevision else { return false }
        // Even a failed newer write prevents a late older snapshot from winning.
        newestRevision = revision
        try withDatabase { db in
            // Refuse to flatten a future multi-pocket library into this one-pocket build.
            guard try rows(db, "SELECT id FROM pockets").count <= 1 else { throw LibraryStoreError.database("multiple pockets") }
            let payload = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
            try insert(db, "INSERT OR REPLACE INTO pending_save VALUES (1, ?)", [payload])
            let failure = nextCommitFailure
            nextCommitFailure = nil
            if failure == .diskFull {
                // Real SQLITE_FULL, scoped to this connection; never fills the host disk.
                let pages = try rows(db, "PRAGMA page_count")[0][0]
                try execute(db, "PRAGMA max_page_count = \(pages)")
            }
            try execute(db, "BEGIN IMMEDIATE")
            do {
                try execute(db, "DELETE FROM text_items; DELETE FROM reference_items; DELETE FROM scratchpads; DELETE FROM pockets;")
                let pocketID = snapshot.pocketID.uuidString
                try insert(db, "INSERT INTO pockets VALUES (?, ?)", [pocketID, snapshot.pocketName])
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
                if failure == .rollback { throw LibraryStoreError.injectedFailure }
                if failure == .interrupted {
                    // SQLite cancels the next VM operation, just as an interrupted write.
                    sqlite3_progress_handler(db, 1, { _ in 1 }, nil)
                }
                defer { sqlite3_progress_handler(db, 0, nil, nil) }
                try execute(db, "DELETE FROM pending_save")
                try execute(db, "COMMIT")
            } catch {
                sqlite3_progress_handler(db, 0, nil, nil)
                try? execute(db, "ROLLBACK")
                throw error
            }
        }
        return true
    }

    func importFile(_ source: URL, confirmed: Bool = false) async throws -> ReferenceItem {
        try await assets.importSource(.file(source), confirmed: confirmed)
    }

    func importSource(_ source: ReferenceImportSource, confirmed: Bool = false) async throws -> ReferenceItem {
        try await assets.importSource(source, confirmed: confirmed)
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
        guard version <= 4 else { throw LibraryStoreError.newerVersion }
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
                CREATE TABLE pending_save (id INTEGER PRIMARY KEY CHECK(id = 1), payload TEXT NOT NULL);
                PRAGMA user_version = 4;
                COMMIT;
                """)
        }
        if (1...2).contains(version) {
            // One snapshot of the untouched database before any migration step.
            try snapshotBeforeMigration(db, version: version)
            if version == 1 {
                try execute(db, """
                    BEGIN IMMEDIATE;
                    ALTER TABLE text_items ADD COLUMN uses_fields INTEGER NOT NULL DEFAULT 0;
                    UPDATE text_items SET uses_fields = 1 WHERE kind = 'prompt' AND instr(body, '{{') > 0;
                    PRAGMA user_version = 2;
                    COMMIT;
                    """)
            }
            // Version 3: instructions and prompts became one list. Former instructions
            // follow the existing prompts in their own order, as plain prompts (no blanks).
            try execute(db, """
                BEGIN IMMEDIATE;
                UPDATE text_items SET position = position + (SELECT COUNT(*) FROM text_items WHERE kind = 'prompt')
                    WHERE kind = 'instruction';
                UPDATE text_items SET kind = 'prompt', uses_fields = 0 WHERE kind = 'instruction';
                PRAGMA user_version = 3;
                COMMIT;
                """)
        }
        if (1...3).contains(version) {
            if version == 3 { try snapshotBeforeMigration(db, version: version) }
            try execute(db, """
                BEGIN IMMEDIATE;
                CREATE TABLE pending_save (id INTEGER PRIMARY KEY CHECK(id = 1), payload TEXT NOT NULL);
                PRAGMA user_version = 4;
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
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            if result == SQLITE_FULL { throw LibraryStoreError.diskFull }
            throw LibraryStoreError.database("execute")
        }
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
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            if result == SQLITE_FULL { throw LibraryStoreError.diskFull }
            throw LibraryStoreError.database("insert")
        }
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
