import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Phase 7 manual update recovery")
struct Phase7DistributionTests {
    private func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "nivlet-phase7-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func sql(_ root: URL, _ statement: String) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(root.appending(path: "library.sqlite").path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK)
    }

    @Test("Same-schema update keeps last-good, pending, trash and originals; a closed-library backup remains independent",
          arguments: [LibraryStore.CommitFailure.rollback, .interrupted])
    func sameSchemaUpdate(failure: LibraryStore.CommitFailure) async throws {
        let base = try folder(); defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appending(path: "library"), store = LibraryStore(root: base.appending(path: "library"))
        var first = try await store.load()
        first.prompts = [SavedPrompt(label: "Review", source: "Exact 👩🏽‍💻\r\n{{literal}}  ", isFavorite: true)]
        first.note = "[x] Before update\r\n[ ] Next"
        let bytes = Data([0, 255, 10, 13, 128, 1])
        let source = base.appending(path: "Original.bin"); try bytes.write(to: source)
        first.references = [try await store.importFile(source)]
        try FileManager.default.removeItem(at: source)
        var second = LibrarySnapshot.empty; second.pocketName = "Other pocket"
        second.view = PocketViewBookmark(tool: .notes, query: "remember", scope: .all)
        var removed = LibrarySnapshot.empty; removed.pocketName = "Recoverable pocket"
        removed.prompts = [SavedPrompt(label: "Deleted kit", source: "Keep through update")]
        let original = PocketCollection(pockets: [second, first],
            trash: [TrashedPocket(pocket: removed, deletedAt: Date(timeIntervalSince1970: 1_793_361_000))], activePocketID: first.pocketID)
        #expect(try await store.saveCollection(original, revision: 1))
        var pending = original; pending.pockets[1].note += "\nUnsaved before quit ✅"
        await store.failNextCommitForTesting(failure)
        await #expect(throws: LibraryStoreError.self) { try await store.saveCollection(pending, revision: 2) }

        // Each store operation closes SQLite. Copy the complete closed root, never only the DB.
        let backup = base.appending(path: "pre-update-backup")
        try FileManager.default.copyItem(at: root, to: backup)
        let backupDatabase = try Data(contentsOf: backup.appending(path: "library.sqlite"))
        let replacement = LibraryStore(root: root)
        #expect(try await replacement.loadCollection() == original)
        #expect(try await replacement.recoverableCollection() == pending)
        let kit = PocketLibrary(root: root); await kit.load()
        #expect(kit.collection == pending); #expect(kit.needsRecoveryReview)
        #expect(!(await kit.flush())) // Startup/tuck must not silently accept the pending revision.
        #expect(await kit.retrySaving())
        #expect(try await LibraryStore(root: root).loadCollection() == pending)
        #expect(try await LibraryStore(root: root).recoverableCollection() == nil)
        #expect(try Data(contentsOf: first.references[0].originalURL) == bytes)

        // Exercise rollback in a separate root. Keep post-update edits and backup intact.
        let rollback = base.appending(path: "rollback-copy")
        try FileManager.default.copyItem(at: backup, to: rollback)
        let rollbackStore = LibraryStore(root: rollback)
        let old = try await rollbackStore.loadCollection()
        #expect(old.pockets.map(\.pocketID) == original.pockets.map(\.pocketID))
        #expect(old.pockets[1].note == first.note); #expect(old.trash == original.trash)
        let rollbackKit = PocketLibrary(root: rollback); await rollbackKit.load()
        #expect(rollbackKit.needsRecoveryReview)
        #expect(rollbackKit.note == pending.pockets[1].note)
        let reference = try #require(rollbackKit.references.first)
        #expect(reference.originalURL.path.hasPrefix(rollback.path + "/assets/"))
        #expect(try Data(contentsOf: reference.originalURL) == bytes)
        #expect(try FileHandoff.sha256(of: reference.originalURL) == reference.originalURL.deletingLastPathComponent().lastPathComponent)
        #expect(try Data(contentsOf: backup.appending(path: "library.sqlite")) == backupDatabase)
        #expect(try await LibraryStore(root: root).loadCollection() == pending)
    }

    @Test("Downgrade refusal and save retry leave future metadata, pending recovery and original bytes untouched")
    func futureSchema() async throws {
        let base = try folder(); defer { try? FileManager.default.removeItem(at: base) }
        let store = LibraryStore(root: base)
        var saved = try await store.load()
        let source = base.appending(path: "source.txt"); try Data("Original ✅".utf8).write(to: source)
        saved.references = [try await store.importFile(source)]
        saved.prompts = [SavedPrompt(label: "Future content", source: "Preserve me")]
        #expect(try await store.save(saved, revision: 1))
        var pending = saved; pending.note = "Future recovered draft"
        await store.failNextCommitForTesting()
        await #expect(throws: LibraryStoreError.self) { try await store.save(pending, revision: 2) }
        try sql(base, "PRAGMA user_version = 99; CREATE TABLE future_only (value TEXT); INSERT INTO future_only VALUES ('preserve');")
        let before = try Data(contentsOf: base.appending(path: "library.sqlite"))
        let original = try Data(contentsOf: saved.references[0].originalURL)
        let olderApp = PocketLibrary(root: base); await olderApp.load()
        #expect(!olderApp.isLoaded)
        guard case .failed(let message) = olderApp.saveState else { Issue.record("Expected a visible load failure"); return }
        #expect(message.contains("newer version"))
        #expect(!(await olderApp.retrySaving()))
        #expect(!(await olderApp.flush()))
        #expect(try Data(contentsOf: base.appending(path: "library.sqlite")) == before)
        #expect(try Data(contentsOf: saved.references[0].originalURL) == original)
    }
}
