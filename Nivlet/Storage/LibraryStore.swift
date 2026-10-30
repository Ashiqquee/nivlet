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
    private let archiveIO: PocketArchiveIO
    private var activeArchiveIDs = Set<UUID>()
    private var activeImports = 0
    private var uncommittedImportDigests = Set<String>()
    private var restoringArchive = false
    private var nextMigrationFailure = false
    private var newestRevision: UInt64 = 0
    enum CommitFailure: Sendable { case rollback, diskFull, interrupted }
    private var nextCommitFailure: CommitFailure?

    init(root: URL, assets: ReferenceAssetStore? = nil, archiveIO: PocketArchiveIO? = nil) {
        self.root = root; self.assets = assets ?? ReferenceAssetStore(root: root)
        self.archiveIO = archiveIO ?? PocketArchiveIO(root: root)
    }

    func failNextMigrationForTesting() { nextMigrationFailure = true }
    func failNextArchiveForTesting(_ point: PocketArchiveIO.FailurePoint) async { await archiveIO.failNextForTesting(point) }
    func failNextCommitForTesting(_ failure: CommitFailure = .rollback) { nextCommitFailure = failure }

    /// Compatibility entry point for the original one-pocket slice. Never flattens
    /// a multi-pocket library: all production writes use saveCollection.
    func load() throws -> LibrarySnapshot {
        let collection = try loadCollection()
        return collection.pockets.first { $0.pocketID == collection.activePocketID }!
    }

    func loadCollection() throws -> PocketCollection {
        try withDatabase { db in
            let pocketRows = try rows(db, "SELECT id, name, deleted_at, view_state FROM pockets ORDER BY position")
            if pocketRows.isEmpty {
                let pocket = LibrarySnapshot.empty
                try execute(db, "BEGIN IMMEDIATE")
                do {
                    try insert(db, "INSERT INTO pockets (id,name,position) VALUES (?, ?, ?)", [pocket.pocketID.uuidString, pocket.pocketName, "0"])
                    try insert(db, "INSERT INTO scratchpads VALUES (?, ?)", [pocket.pocketID.uuidString, ""])
                    try insert(db, "INSERT OR REPLACE INTO library_state VALUES (1, ?)", [pocket.pocketID.uuidString])
                    try execute(db, "COMMIT")
                } catch { try? execute(db, "ROLLBACK"); throw error }
                return PocketCollection(pocket: pocket)
            }
            var live: [LibrarySnapshot] = []
            var trash: [TrashedPocket] = []
            // Bulk reads, grouped by explicit owner. No unscoped LIMIT 1 or implicit
            // association with the current pocket.
            let texts = try rows(db, "SELECT id,pocket_id,label,body,favorite,uses_fields FROM text_items ORDER BY position")
            let notes = try rows(db, "SELECT pocket_id,body FROM scratchpads")
            let refs = try rows(db, "SELECT id,pocket_id,label,note,display_name,asset,is_image,favorite,byte_count FROM reference_items ORDER BY position")
            for row in pocketRows {
                guard let id = UUID(uuidString: row[0]) else { throw LibraryStoreError.database("invalid pocket") }
                var pocket = LibrarySnapshot(pocketID: id, pocketName: row[1], prompts: [], references: [], note: "")
                for item in texts where item[1] == row[0] {
                    guard let itemID = UUID(uuidString: item[0]) else { throw LibraryStoreError.database("invalid identity") }
                    pocket.prompts.append(SavedPrompt(id: itemID, label: item[2], source: item[3],
                                                     isFavorite: item[4] == "1", usesFields: item[5] == "1"))
                }
                pocket.note = notes.first { $0[0] == row[0] }?[1] ?? ""
                for item in refs where item[1] == row[0] {
                    guard let itemID = UUID(uuidString: item[0]), Self.isDigest(item[5]) else { throw LibraryStoreError.database("invalid asset") }
                    let original = root.appending(path: "assets/\(item[5])/original")
                    pocket.references.append(ReferenceItem(id: itemID, label: item[2], note: item[3], displayName: item[4],
                        originalURL: original, isImage: ReferenceAssetStore.isImageFile(original), byteCount: Int64(item[8]), isFavorite: item[7] == "1"))
                }
                if !row[3].isEmpty { pocket.view = try JSONDecoder().decode(PocketViewBookmark.self, from: Data(row[3].utf8)) }
                if row[2].isEmpty { live.append(pocket) }
                else {
                    guard let timestamp = Double(row[2]), timestamp.isFinite else { throw LibraryStoreError.database("trash date") }
                    trash.append(TrashedPocket(pocket: pocket, deletedAt: Date(timeIntervalSince1970: timestamp)))
                }
            }
            guard let first = live.first else { throw LibraryStoreError.database("no live pocket") }
            let active = try rows(db, "SELECT active_pocket FROM library_state WHERE id = 1").first?.first.flatMap(UUID.init(uuidString:))
            let collection = PocketCollection(pockets: live, trash: trash,
                activePocketID: live.contains { $0.pocketID == active } ? active! : first.pocketID)
            try collection.validate()
            return collection
        }
    }

    func recoverableCollection() throws -> PocketCollection? {
        try withDatabase { db in
            guard let json = try rows(db, "SELECT payload FROM pending_save WHERE id = 1").first?.first else { return nil }
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            var collection: PocketCollection
            if let legacy = try? decoder.decode(LibrarySnapshot.self, from: data) {
                // A pre-Phase-4 pending revision belongs to the same sole pocket.
                guard try rows(db, "SELECT id FROM pockets").count <= 1 else { throw LibraryStoreError.database("legacy recovery ownership") }
                collection = PocketCollection(pocket: legacy)
            } else { collection = try decoder.decode(PocketCollection.self, from: data) }
            try collection.validate()
            // Pending metadata is local, but a recovery copy may have moved to
            // another root. Resolve owned originals by validated digest rather
            // than retaining the old machine/location's absolute URL.
            func rebase(_ pocket: inout LibrarySnapshot) throws {
                for index in pocket.references.indices {
                    let old = pocket.references[index].originalURL
                    let digest = old.deletingLastPathComponent().lastPathComponent
                    guard old.lastPathComponent == "original", ArchiveDisk.isDigest(digest) else { throw PocketArchiveError.invalid }
                    pocket.references[index].originalURL = root.appending(path: "assets/\(digest)/original")
                }
            }
            for index in collection.pockets.indices { try rebase(&collection.pockets[index]) }
            for index in collection.trash.indices { try rebase(&collection.trash[index].pocket) }
            return collection
        }
    }

    func recoverableSnapshot() throws -> LibrarySnapshot? {
        guard let collection = try recoverableCollection() else { return nil }
        guard collection.pockets.count == 1, collection.trash.isEmpty else { throw LibraryStoreError.database("multiple pockets") }
        return collection.pockets.first
    }

    @discardableResult
    func save(_ snapshot: LibrarySnapshot, revision: UInt64) throws -> Bool {
        // Retained for one-pocket clients/tests; refuse ambiguous ownership changes.
        let existing = try loadCollection()
        guard existing.pockets.count == 1, existing.trash.isEmpty else { throw LibraryStoreError.database("multiple pockets") }
        return try saveCollection(PocketCollection(pocket: snapshot), revision: revision)
    }

    /// Journal the entire ownership graph first, then replace metadata and clear
    /// the intent atomically. No filesystem deletion occurs in this transaction.
    @discardableResult
    func saveCollection(_ collection: PocketCollection, revision: UInt64) throws -> Bool {
        try commitCollection(collection, revision: revision, journal: true)
    }

    private func commitCollection(_ collection: PocketCollection, revision: UInt64, journal: Bool) throws -> Bool {
        guard revision >= newestRevision else { return false }
        try collection.validate()
        newestRevision = revision
        try withDatabase { db in
            if journal {
                let payload = String(decoding: try JSONEncoder().encode(collection), as: UTF8.self)
                try insert(db, "INSERT OR REPLACE INTO pending_save VALUES (1, ?)", [payload])
            }
            let failure = nextCommitFailure
            nextCommitFailure = nil
            if failure == .diskFull {
                let pages = try rows(db, "PRAGMA page_count")[0][0]
                try execute(db, "PRAGMA max_page_count = \(pages)")
            }
            try execute(db, "BEGIN IMMEDIATE")
            do {
                try execute(db, "DELETE FROM text_items; DELETE FROM reference_items; DELETE FROM scratchpads; DELETE FROM pockets; DELETE FROM library_state;")
                let all = collection.pockets.map { ($0, Optional<Date>.none) } + collection.trash.map { ($0.pocket, Optional($0.deletedAt)) }
                for (position, entry) in all.enumerated() {
                    let (pocket, deletedAt) = entry
                    let pocketID = pocket.pocketID.uuidString
                    try insert(db, "INSERT INTO pockets (id,name,position,deleted_at,view_state) VALUES (?,?,?,NULLIF(?,''),NULLIF(?,''))",
                               [pocketID, pocket.pocketName, "\(position)", deletedAt.map { String($0.timeIntervalSince1970) } ?? "", try pocket.view.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) } ?? ""])
                    for (position, item) in pocket.prompts.enumerated() {
                        try insert(db, "INSERT INTO text_items VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                            [item.id.uuidString, pocketID, "prompt", item.label, item.source, item.isFavorite ? "1" : "0", "\(position)", item.usesFields ? "1" : "0"])
                    }
                    try insert(db, "INSERT INTO scratchpads VALUES (?, ?)", [pocketID, pocket.note])
                    for (position, item) in pocket.references.enumerated() {
                        let digest = item.originalURL.deletingLastPathComponent().lastPathComponent
                        guard Self.isDigest(digest), item.originalURL.standardizedFileURL == root.appending(path: "assets/\(digest)/original").standardizedFileURL
                            else { throw LibraryStoreError.invalidFile }
                        try insert(db, "INSERT INTO reference_items (id,pocket_id,label,note,display_name,asset,is_image,position,favorite,byte_count) VALUES (?,?,?,?,?,?,?,?,?,NULLIF(?,''))",
                            [item.id.uuidString, pocketID, item.label, item.note, item.displayName, digest, item.isImage ? "1" : "0", "\(position)", item.isFavorite ? "1" : "0", item.byteCount.map(String.init) ?? ""])
                    }
                }
                try insert(db, "INSERT INTO library_state VALUES (1, ?)", [collection.activePocketID.uuidString])
                if failure == .rollback { throw LibraryStoreError.injectedFailure }
                if failure == .interrupted { sqlite3_progress_handler(db, 1, { _ in 1 }, nil) }
                defer { sqlite3_progress_handler(db, 0, nil, nil) }
                try execute(db, "DELETE FROM pending_save")
                try execute(db, "COMMIT")
            } catch {
                sqlite3_progress_handler(db, 0, nil, nil)
                try? execute(db, "ROLLBACK")
                throw error
            }
        }
        uncommittedImportDigests.subtract(collection.assetReferenceCounts.keys.map { $0.deletingLastPathComponent().lastPathComponent })
        return true
    }

    func importFile(_ source: URL, confirmed: Bool = false) async throws -> ReferenceItem {
        try await importSource(.file(source), confirmed: confirmed)
    }

    func importSource(_ source: ReferenceImportSource, confirmed: Bool = false) async throws -> ReferenceItem {
        guard !restoringArchive else { throw PocketArchiveError.busy }
        activeImports += 1
        defer { activeImports -= 1 }
        let item = try await assets.importSource(source, confirmed: confirmed)
        uncommittedImportDigests.insert(item.originalURL.deletingLastPathComponent().lastPathComponent)
        return item
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
        guard version <= 5 else { throw LibraryStoreError.newerVersion }
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
        if (1...4).contains(version) { try snapshotBeforeMigration(db, version: version) }
        if version <= 4 {
            try execute(db, "BEGIN IMMEDIATE")
            do {
                if version == 1 {
                    try execute(db, """
                        ALTER TABLE text_items ADD COLUMN uses_fields INTEGER NOT NULL DEFAULT 0;
                        UPDATE text_items SET uses_fields = 1 WHERE kind = 'prompt' AND instr(body, '{{') > 0;
                        """)
                }
                if (1...2).contains(version) {
                    try execute(db, """
                        UPDATE text_items SET position = position + (SELECT COUNT(*) FROM text_items WHERE kind = 'prompt') WHERE kind = 'instruction';
                        UPDATE text_items SET kind = 'prompt', uses_fields = 0 WHERE kind = 'instruction';
                        """)
                }
                if (1...3).contains(version) {
                    try execute(db, "CREATE TABLE pending_save (id INTEGER PRIMARY KEY CHECK(id = 1), payload TEXT NOT NULL)")
                }
                try execute(db, """
                    ALTER TABLE pockets ADD COLUMN position INTEGER NOT NULL DEFAULT 0;
                    ALTER TABLE pockets ADD COLUMN deleted_at REAL;
                    ALTER TABLE pockets ADD COLUMN view_state TEXT;
                    ALTER TABLE reference_items ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
                    ALTER TABLE reference_items ADD COLUMN byte_count INTEGER;
                    CREATE TABLE library_state (id INTEGER PRIMARY KEY CHECK(id = 1), active_pocket TEXT NOT NULL);
                    INSERT INTO library_state SELECT 1,id FROM pockets ORDER BY rowid LIMIT 1;
                    PRAGMA user_version = 5;
                    """)
                if nextMigrationFailure { nextMigrationFailure = false; throw LibraryStoreError.injectedFailure }
                try execute(db, "COMMIT")
            } catch { try? execute(db, "ROLLBACK"); throw error }
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

extension LibraryStore {
    func prepareExport(_ pockets: [LibrarySnapshot]) async throws -> ArchivePreview {
        guard !restoringArchive else { throw PocketArchiveError.busy }
        let id = UUID()
        let digests = Set(pockets.flatMap(\.references).map { $0.originalURL.deletingLastPathComponent().lastPathComponent })
        guard digests.allSatisfy(ArchiveDisk.isDigest) else { throw PocketArchiveError.corruptAsset }
        try ArchiveLeases.write(ArchiveLease(id: id, digests: digests, protectsAllAssets: false), root: root)
        activeArchiveIDs.insert(id)
        do {
            let preview = try await archiveIO.prepareExport(id: id, pockets: pockets)
            try Task.checkCancellation()
            return preview
        }
        catch { try? await closeArchive(id); throw error }
    }

    func exportArchive(_ id: UUID, to destination: URL) async throws {
        guard activeArchiveIDs.contains(id) else { throw PocketArchiveError.expired }
        try await archiveIO.export(id: id, to: destination)
    }

    func prepareRestore(from source: URL) async throws -> ArchivePreview {
        guard !restoringArchive else { throw PocketArchiveError.busy }
        let id = UUID()
        try ArchiveLeases.write(ArchiveLease(id: id, digests: [], protectsAllAssets: true), root: root)
        activeArchiveIDs.insert(id)
        do {
            let preview = try await archiveIO.prepareRestore(id: id, from: source)
            try Task.checkCancellation()
            try ArchiveLeases.write(ArchiveLease(id: id, digests: Set(preview.manifest.assets.map(\.digest)), protectsAllAssets: false), root: root)
            return preview
        } catch { try? await closeArchive(id); throw error }
    }

    /// This commit intentionally does not journal an unaccepted destination
    /// revision: a failed restore must remain absent after relaunch as well.
    /// Placed assets are harmless orphans pinned until operation reconciliation.
    func commitRestore(_ id: UUID, revision: UInt64) async throws -> PocketCollection {
        guard activeArchiveIDs.contains(id), !restoringArchive, activeImports == 0,
              try recoverableCollection() == nil else { throw PocketArchiveError.busy }
        restoringArchive = true
        defer { restoringArchive = false }
        let pockets = try await archiveIO.placeRestore(id: id)
        try Task.checkCancellation()
        // Read after placement, so any metadata work that completed while the
        // actor was suspended is retained instead of overwritten.
        var collection = try loadCollection()
        collection.pockets.append(contentsOf: pockets)
        guard try commitCollection(collection, revision: revision, journal: false) else { throw PocketArchiveError.busy }
        // Commit is the cancellation boundary. Never report cancellation after
        // the pockets became durable, even if cleanup is deferred.
        try? await closeArchive(id)
        return collection
    }

    func closeArchive(_ id: UUID) async throws {
        guard activeArchiveIDs.contains(id) else { return }
        try await archiveIO.discard(id)
        try ArchiveLeases.remove(id, root: root)
        activeArchiveIDs.remove(id)
    }

    /// Only called once at startup, before the UI starts archive operations.
    /// Retained placed bytes are handled by the age-gated graph cleanup later.
    func reconcileInterruptedArchives() async throws {
        guard activeArchiveIDs.isEmpty, activeImports == 0, !restoringArchive else { throw PocketArchiveError.busy }
        for lease in try ArchiveLeases.readAll(root: root) {
            guard !ArchiveLeases.ownerIsRunning(lease) else { continue }
            try await archiveIO.discard(lease.id)
            try ArchiveLeases.remove(lease.id, root: root)
        }
    }

    /// Scan legacy backup ownership too: migration rollback requires originals,
    /// not merely a database file. Malformed/unknown backups stop cleanup.
    private func migrationAssetDigests() throws -> Set<String> {
        let folder = root.appending(path: "snapshots")
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        try ArchiveDisk.directory(folder)
        var retained = Set<String>()
        for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            let (reader, _) = try ArchiveDisk.reader(file); try reader.close()
            var db: OpaquePointer?
            guard sqlite3_open_v2(file.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else { throw PocketArchiveError.invalid }
            defer { sqlite3_close(db) }
            guard try rows(db, "PRAGMA integrity_check").first?.first == "ok" else { throw PocketArchiveError.invalid }
            let version = Int(try rows(db, "PRAGMA user_version")[0][0]) ?? 0
            guard (1...5).contains(version) else { throw PocketArchiveError.unsupportedVersion }
            for row in try rows(db, "SELECT asset FROM reference_items") {
                guard ArchiveDisk.isDigest(row[0]) else { throw PocketArchiveError.invalid }
                retained.insert(row[0])
            }
            if version >= 4, let payload = try rows(db, "SELECT payload FROM pending_save WHERE id = 1").first?.first {
                retained.formUnion(try pendingDigests(Data(payload.utf8)))
            }
        }
        return retained
    }

    private func pendingDigests(_ data: Data) throws -> Set<String> {
        let decoder = JSONDecoder()
        let refs: [ReferenceItem]
        if let pocket = try? decoder.decode(LibrarySnapshot.self, from: data) { refs = pocket.references }
        else {
            let collection = try decoder.decode(PocketCollection.self, from: data)
            try collection.validate()
            refs = (collection.pockets + collection.trash.map(\.pocket)).flatMap(\.references)
        }
        let digests = Set(refs.map { $0.originalURL.deletingLastPathComponent().lastPathComponent })
        guard digests.allSatisfy(ArchiveDisk.isDigest) else { throw PocketArchiveError.invalid }
        return digests
    }

    func cleanupAssets(retaining extra: Set<URL>, now: Date = .now, minimumAge: TimeInterval = 86400) throws -> AssetCleanupResult {
        try Task.checkCancellation()
        guard activeImports == 0, !restoringArchive else { throw PocketArchiveError.busy }
        let collection = try loadCollection()
        var digests = Set(collection.assetReferenceCounts.keys.map { $0.deletingLastPathComponent().lastPathComponent })
        digests.formUnion(uncommittedImportDigests)
        digests.formUnion(extra.map { $0.deletingLastPathComponent().lastPathComponent })
        if let pending = try recoverableCollection() { digests.formUnion(pending.assetReferenceCounts.keys.map { $0.deletingLastPathComponent().lastPathComponent }) }
        digests.formUnion(try migrationAssetDigests())
        let leases = try ArchiveLeases.readAll(root: root)
        guard !leases.contains(where: \.protectsAllAssets) else { throw PocketArchiveError.busy }
        for lease in leases { digests.formUnion(lease.digests) }
        var result = AssetCleanupResult()
        let manager = FileManager.default
        let assetsRoot = root.appending(path: "assets")
        if manager.fileExists(atPath: assetsRoot.path) {
            try ArchiveDisk.directory(assetsRoot)
            for folder in try manager.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]) {
                try Task.checkCancellation()
                let digest = folder.lastPathComponent
                guard ArchiveDisk.isDigest(digest), !digests.contains(digest) else { continue }
                let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey, .contentModificationDateKey])
                guard values.isDirectory == true, values.isSymbolicLink != true,
                      let date = values.creationDate, now.timeIntervalSince(max(date, values.contentModificationDate ?? date)) > minimumAge else { continue }
                let children = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                guard children.count == 1, children[0].lastPathComponent == "original" else { continue }
                let (file, size) = try ArchiveDisk.reader(children[0]); try file.close()
                try manager.removeItem(at: folder)
                result.removedAssets += 1; result.reclaimedBytes += size
            }
        }
        // Interrupted reference imports contain only an app-generated UUID and
        // one regular staged original. Unknown entries are never traversed.
        let staging = root.appending(path: "staging")
        if manager.fileExists(atPath: staging.path) {
            try ArchiveDisk.directory(staging)
            for folder in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: [.creationDateKey]) {
                try Task.checkCancellation()
                guard UUID(uuidString: folder.lastPathComponent) != nil else { continue }
                let values = try folder.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .creationDateKey])
                guard values.isSymbolicLink != true, values.isDirectory == true, let date = values.creationDate,
                      now.timeIntervalSince(date) > minimumAge else { continue }
                let children = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                guard children.allSatisfy({ $0.lastPathComponent == "original" }) else { continue }
                for child in children { let (file, _) = try ArchiveDisk.reader(child); try file.close() }
                try manager.removeItem(at: folder); result.removedStagingFolders += 1
            }
        }
        return result
    }
}
