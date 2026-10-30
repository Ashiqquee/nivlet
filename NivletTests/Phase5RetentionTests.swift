import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Phase 5 retention and migration")
struct Phase5RetentionTests {
    private func base() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "nivlet-phase5-retention-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func imported(_ text: String, base: URL, store: LibraryStore) async throws -> ReferenceItem {
        let file = base.appending(path: "\(UUID().uuidString).txt"); try Data(text.utf8).write(to: file)
        return try await store.importFile(file)
    }
    private var future: Date { Date().addingTimeInterval(2 * 86400) }

    @Test("Cleanup retains live/trash/shared assets and an active export, then releases only the unowned bytes")
    func ownershipGraph() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), store = LibraryStore(root: folder.appending(path: "library"))
        var a = try await store.load()
        let live = try await imported("Live", base: folder, store: store)
        let trashed = try await imported("Trash", base: folder, store: store)
        let exporting = try await imported("Exporting", base: folder, store: store)
        a.references = [live, trashed, exporting]
        #expect(try await store.save(a, revision: 1)) // release import pins after ownership is committed
        var deleted = LibrarySnapshot.empty; deleted.pocketName = "Deleted"; deleted.references = [trashed]
        let exportPocket = LibrarySnapshot(pocketID: UUID(), pocketName: "Exporting", prompts: [], references: [exporting], note: "")
        a.references = [live]
        var b = LibrarySnapshot.empty; b.pocketName = "Shared"
        b.references = [ReferenceItem(id: UUID(), label: "Shared", note: "Own note", displayName: "Shared.txt", originalURL: live.originalURL, isImage: false)]
        let collection = PocketCollection(pockets: [a,b], trash: [TrashedPocket(pocket: deleted, deletedAt: Date(timeIntervalSince1970: 1_800_000_000))], activePocketID: a.pocketID)
        #expect(try await store.saveCollection(collection, revision: 2))
        let preview = try await store.prepareExport([exportPocket])
        #expect(try await store.cleanupAssets(retaining: [], now: future).removedAssets == 0)
        #expect(FileManager.default.fileExists(atPath: exporting.originalURL.path))
        try await store.closeArchive(preview.id)
        #expect(try await store.cleanupAssets(retaining: [], now: future).removedAssets == 1)
        #expect(!FileManager.default.fileExists(atPath: exporting.originalURL.path))
        #expect(try Data(contentsOf: live.originalURL) == Data("Live".utf8))
        #expect(try Data(contentsOf: trashed.originalURL) == Data("Trash".utf8))
        #expect(try await LibraryStore(root: root).loadCollection() == collection)
    }

    @Test("Pending-save intent, in-session Undo and freshly placed files remain retained")
    @MainActor func pendingAndUndo() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), store = LibraryStore(root: folder.appending(path: "library"))
        let kit = PocketLibrary(root: root, store: store); await kit.load()
        let source = folder.appending(path: "Original.txt"); try Data("Undo original".utf8).write(to: source)
        await kit.importFiles([source]); let reference = try #require(kit.references.first)
        kit.delete(id: reference.id, tool: .references); #expect(await kit.flush())
        await kit.cleanUnusedFiles(now: future)
        #expect(FileManager.default.fileExists(atPath: reference.originalURL.path)); #expect(kit.canUndoDelete)
        kit.undoDelete(); #expect(kit.references.first?.id == reference.id); #expect(await kit.flush())
        var pending = try await store.loadCollection()
        let extra = try await imported("Pending only", base: folder, store: store)
        pending.pockets[0].references.append(extra)
        await store.failNextCommitForTesting()
        await #expect(throws: LibraryStoreError.self) { try await store.saveCollection(pending, revision: 100) }
        let reopened = LibraryStore(root: root)
        #expect(try await reopened.cleanupAssets(retaining: [], now: future).removedAssets == 0)
        #expect(try Data(contentsOf: extra.originalURL) == Data("Pending only".utf8))
        #expect(try await reopened.recoverableCollection() == pending)
    }

    @Test("Uncommitted deduplicated imports are pinned even before metadata intent exists")
    func importGap() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder.appending(path: "library")); var pocket = try await store.load()
        let item = try await imported("Old orphan reused", base: folder, store: store)
        pocket.references = [item]; #expect(try await store.save(pocket, revision: 1))
        pocket.references = []; #expect(try await store.save(pocket, revision: 2))
        let reused = try await imported("Old orphan reused", base: folder, store: store)
        #expect(reused.originalURL == item.originalURL)
        #expect(try await store.cleanupAssets(retaining: [], now: future).removedAssets == 0)
        // A crashed, uncommitted import is unowned, and only a later age-gated
        // cleanup on the next instance may remove it.
        let restarted = LibraryStore(root: folder.appending(path: "library"))
        #expect(try await restarted.cleanupAssets(retaining: [], now: .now).removedAssets == 0)
        #expect(try await restarted.cleanupAssets(retaining: [], now: future).removedAssets == 1)
    }

    @Test("Durable interrupted-export pins survive reopening until explicit reconciliation")
    func interruptedExport() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), store = LibraryStore(root: folder.appending(path: "library"))
        var pocket = try await store.load(); let item = try await imported("Pinned", base: folder, store: store)
        pocket.references = [item]; #expect(try await store.save(pocket, revision: 1))
        let preview = try await store.prepareExport([pocket])
        pocket.references = []; #expect(try await store.save(pocket, revision: 2))
        let restarted = LibraryStore(root: root)
        #expect(try await restarted.cleanupAssets(retaining: [], now: future).removedAssets == 0)
        #expect(try ArchiveLeases.readAll(root: root).map(\.id) == [preview.id])
        try await restarted.reconcileInterruptedArchives()
        #expect(try await restarted.cleanupAssets(retaining: [], now: future).removedAssets == 0) // live owner is protected
        for var lease in try ArchiveLeases.readAll(root: root) {
            lease.ownerPID = Int32.max; try ArchiveLeases.write(lease, root: root)
        }
        try await restarted.reconcileInterruptedArchives()
        #expect(try await restarted.cleanupAssets(retaining: [], now: future).removedAssets == 1)
    }

    @Test("Corrupt retention records stop cleanup while the working library stays usable")
    @MainActor func corruptPin() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), store = LibraryStore(root: folder.appending(path: "library"))
        var pocket = try await store.load(); pocket.note = "Working content"; #expect(try await store.save(pocket, revision: 1))
        let operations = ArchiveLeases.directory(root: root); try FileManager.default.createDirectory(at: operations, withIntermediateDirectories: true)
        try Data("broken pin".utf8).write(to: operations.appending(path: "unknown.json"))
        await #expect(throws: (any Error).self) { try await store.cleanupAssets(retaining: [], now: future) }
        let kit = PocketLibrary(root: root); await kit.load()
        #expect(kit.isLoaded); #expect(kit.note == "Working content"); #expect(kit.maintenanceNotice != nil)
    }

    @Test("Cleanup expires trash metadata first and preserves another owner's shared original")
    @MainActor func expiredTrash() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), kit = PocketLibrary(root: folder.appending(path: "library")); await kit.load()
        let source = folder.appending(path: "Shared.txt"); try Data("Shared".utf8).write(to: source)
        await kit.importFiles([source]); let item = try #require(kit.references.first)
        let copy = try #require(kit.duplicatePocket())
        #expect(await kit.deletePocket(now: Date().addingTimeInterval(-8 * 86400)))
        #expect(kit.pocketID == copy)
        await kit.cleanUnusedFiles(now: future)
        #expect(kit.collection.trash.isEmpty); #expect(kit.references.count == 1)
        #expect(try Data(contentsOf: item.originalURL) == Data("Shared".utf8))
        #expect(try await LibraryStore(root: root).loadCollection().trash.isEmpty)
    }

    @Test("Unknown staging content and symlink directories are not traversed or deleted")
    func stagingBoundaries() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), store = LibraryStore(root: folder.appending(path: "library")); _ = try await store.load()
        let outside = folder.appending(path: "outside"); try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appending(path: "original"); try Data("Keep".utf8).write(to: sentinel)
        let assets = root.appending(path: "assets"); try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: assets.appending(path: String(repeating: "a", count: 64)), withDestinationURL: outside)
        let staging = root.appending(path: "staging"); try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let known = staging.appending(path: UUID().uuidString); try FileManager.default.createDirectory(at: known, withIntermediateDirectories: true)
        try Data("Interrupted bytes".utf8).write(to: known.appending(path: "original"))
        let unknown = staging.appending(path: UUID().uuidString); try FileManager.default.createDirectory(at: unknown, withIntermediateDirectories: true)
        try Data("Keep unknown".utf8).write(to: unknown.appending(path: "unexpected"))
        try FileManager.default.createSymbolicLink(at: staging.appending(path: UUID().uuidString), withDestinationURL: outside)
        let result = try await store.cleanupAssets(retaining: [], now: future)
        #expect(result.removedStagingFolders == 1); #expect(result.removedAssets == 0)
        #expect(try Data(contentsOf: sentinel) == Data("Keep".utf8)); #expect(FileManager.default.fileExists(atPath: unknown.path))
    }

    private func legacy(_ root: URL, item: ReferenceItem?) throws -> UUID {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var db: OpaquePointer?; try #require(sqlite3_open(root.appending(path: "library.sqlite").path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let pocket = UUID(), prompt = UUID()
        let sql = """
        CREATE TABLE pockets (id TEXT PRIMARY KEY,name TEXT NOT NULL);
        CREATE TABLE text_items (id TEXT PRIMARY KEY,pocket_id TEXT NOT NULL,kind TEXT NOT NULL,label TEXT NOT NULL,body TEXT NOT NULL,favorite INTEGER NOT NULL,position INTEGER NOT NULL);
        CREATE TABLE scratchpads (pocket_id TEXT PRIMARY KEY,body TEXT NOT NULL);
        CREATE TABLE reference_items (id TEXT PRIMARY KEY,pocket_id TEXT NOT NULL,label TEXT NOT NULL,note TEXT NOT NULL,display_name TEXT NOT NULL,asset TEXT NOT NULL,is_image INTEGER NOT NULL,position INTEGER NOT NULL);
        INSERT INTO pockets VALUES ('\(pocket)', 'Legacy');
        INSERT INTO text_items VALUES ('\(prompt)', '\(pocket)', 'instruction','Rule','Keep literal {{braces}} ✅',1,0);
        INSERT INTO scratchpads VALUES ('\(pocket)', '[x] Preserve checklist ✅');
        PRAGMA user_version = 1;
        """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        if let item {
            let digest = item.originalURL.deletingLastPathComponent().lastPathComponent
            #expect(sqlite3_exec(db, "INSERT INTO reference_items VALUES ('\(item.id)','\(pocket)','Reference','Note','Original.txt','\(digest)',0,0)", nil,nil,nil) == SQLITE_OK)
        }
        return pocket
    }
    private func schema(_ url: URL) throws -> Int32 {
        var db: OpaquePointer?; try #require(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }; var query: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &query, nil) == SQLITE_OK)
        defer { sqlite3_finalize(query) }; try #require(sqlite3_step(query) == SQLITE_ROW)
        return sqlite3_column_int(query,0)
    }

    @Test("All migration steps roll back on failure and a consistent snapshot can rebuild a disposable installation")
    func migrationRollback() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"); let id = try legacy(root, item: nil)
        let store = LibraryStore(root: root); await store.failNextMigrationForTesting()
        await #expect(throws: LibraryStoreError.self) { try await store.loadCollection() }
        #expect(try schema(root.appending(path: "library.sqlite")) == 1)
        let backups = try FileManager.default.contentsOfDirectory(at: root.appending(path: "snapshots"), includingPropertiesForKeys: nil)
        #expect(backups.count == 1); #expect(try schema(try #require(backups.first)) == 1)
        let rollbackRoot = folder.appending(path: "rollback"); try FileManager.default.createDirectory(at: rollbackRoot, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: backups[0], to: rollbackRoot.appending(path: "library.sqlite"))
        let recovered = try await LibraryStore(root: rollbackRoot).load()
        #expect(recovered.pocketID == id); #expect(recovered.prompts.first?.source == "Keep literal {{braces}} ✅")
        #expect(recovered.prompts.first?.usesFields == false); #expect(recovered.note == "[x] Preserve checklist ✅")
        #expect(try schema(rollbackRoot.appending(path: "library.sqlite")) == 5)
    }

    @Test("Migration backups retain original bytes even after those references leave the current library")
    func snapshotAssets() async throws {
        let folder = try base(); defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "library"), assetStore = ReferenceAssetStore(root: folder.appending(path: "library"))
        let source = folder.appending(path: "Original.txt"); try Data("Migration original ✅".utf8).write(to: source)
        let item = try await assetStore.importSource(.file(source), confirmed: false)
        _ = try legacy(root, item: item)
        let store = LibraryStore(root: root); var loaded = try await store.load(); loaded.references = []
        #expect(try await store.save(loaded, revision: 1))
        #expect(try await store.cleanupAssets(retaining: [], now: future).removedAssets == 0)
        #expect(try Data(contentsOf: item.originalURL) == Data("Migration original ✅".utf8))
    }
}
