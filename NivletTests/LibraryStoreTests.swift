import CryptoKit
import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Local user library")
struct LibraryStoreTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "nivlet-library-\(UUID().uuidString)")
    }

    @Test("User text, identity, order and scratchpad survive reopening")
    func roundTrip() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var value = LibrarySnapshot.empty
        value.pocketName = "My real pocket"
        value.instructions = [Instruction(id: UUID(), label: "Rules", body: "One\r\nTwo 👩🏽‍💻\0Three", isFavorite: true)]
        value.prompts = [SavedPrompt(label: "My prompt", source: "Keep {{topic}} literal.\n🙂", usesFields: true), SavedPrompt(label: "Plain", source: "No fields.")]
        value.note = "[ ] Next step\n\nKeep spaces  "
        try await store.save(value, revision: 1)
        let reopened = LibraryStore(root: folder)
        let loaded = try await reopened.load()
        #expect(loaded == value)
    }

    @Test("A failed commit rolls back to the last good library")
    func rollback() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var value = LibrarySnapshot.empty
        value.prompts = [SavedPrompt(label: "Last good", source: "Original text")]
        try await store.save(value, revision: 1)
        await store.failNextCommitForTesting()
        var changed = value
        changed.prompts[0].source = "New text"
        await #expect(throws: LibraryStoreError.self) { try await store.save(changed, revision: 2) }
        #expect(try await store.load() == value)
        try await store.save(changed, revision: 3)
        #expect(try await store.load() == changed)
    }

    @Test("Late stale saves cannot overwrite a newer revision, including after failure")
    func staleRevision() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var older = LibrarySnapshot.empty
        older.note = "Old"
        var newer = older
        newer.note = "New"
        try await store.save(newer, revision: 10)
        #expect(try await store.save(older, revision: 9) == false)
        #expect(try await store.load().note == "New")
        await store.failNextCommitForTesting()
        await #expect(throws: LibraryStoreError.self) { try await store.save(newer, revision: 12) }
        #expect(try await store.save(older, revision: 11) == false)
        #expect(try await store.load().note == "New")
    }

    @Test("Import owns original bytes and preserves per-reference filenames")
    func originalIntegrity() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sources = folder.appending(path: "sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        let first = sources.appending(path: "Original ✅.txt")
        let second = sources.appending(path: "Different name.txt")
        let bytes = Data("Original bytes\nUTF-8 🙂\r\n".utf8)
        try bytes.write(to: first); try bytes.write(to: second)
        let before = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date
        let store = LibraryStore(root: folder.appending(path: "library"))
        let a = try await store.importFile(first)
        let b = try await store.importFile(second)
        #expect(a.originalURL == b.originalURL)
        #expect(a.displayName == "Original ✅.txt")
        #expect(b.displayName == "Different name.txt")
        #expect(try Data(contentsOf: first) == bytes)
        #expect(try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date == before)
        var snapshot = LibrarySnapshot.empty
        snapshot.references = [a, b]
        try await store.save(snapshot, revision: 1)
        try FileManager.default.removeItem(at: sources)
        let loaded = try await LibraryStore(root: folder.appending(path: "library")).load()
        #expect(loaded.references.map(\.displayName) == [a.displayName, b.displayName])
        #expect(try Data(contentsOf: loaded.references[0].originalURL) == bytes)
        #expect(!FileManager.default.isWritableFile(atPath: a.originalURL.path))
    }

    @Test("Folder imports are rejected")
    func rejectFolder() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = LibraryStore(root: folder.appending(path: "library"))
        await #expect(throws: LibraryStoreError.self) { try await store.importFile(folder) }
    }
    @Test("Failed new-prompt saves keep one recoverable draft and never say Saved")
    @MainActor
    func failedDraftRetry() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        let library = PocketLibrary(root: folder, store: store)
        await library.load()
        let draft = TextDraft(tool: .prompts, title: "My prompt", text: "Keep exactly this.")
        await store.failNextCommitForTesting()
        #expect(await library.savePrompt(id: draft.saveID, label: draft.title, source: draft.text, favorite: false) == false)
        #expect(library.prompts.count == 1)
        #expect(library.hasUnsavedChanges)
        if case .failed = library.saveState {} else { Issue.record("A failed write must not show Saved") }
        #expect(await library.savePrompt(id: draft.saveID, label: draft.title, source: draft.text, favorite: false))
        #expect(library.prompts.count == 1)
        #expect(!library.hasUnsavedChanges)
        #expect(try await store.load().prompts.count == 1)
    }

    @Test("Undo deletion restores order without rolling back a newer note")
    @MainActor
    func undoDelete() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        let first = UUID(); let second = UUID()
        #expect(await library.savePrompt(id: first, label: "First", source: "A", favorite: false))
        #expect(await library.savePrompt(id: second, label: "Second", source: "B", favorite: false))
        library.delete(id: first, tool: .prompts)
        library.note = "Keep this newer note"
        library.undoDelete()
        #expect(library.prompts.map(\.id) == [first, second])
        #expect(library.note == "Keep this newer note")
        #expect(await library.flush())
    }

    @Test("Version-one migration preserves user data and makes a consistent snapshot")
    func migration() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        #expect(sqlite3_open(folder.appending(path: "library.sqlite").path, &db) == SQLITE_OK)
        let pocket = UUID(); let item = UUID()
        let sql = """
            CREATE TABLE pockets (id TEXT PRIMARY KEY, name TEXT NOT NULL);
            CREATE TABLE text_items (id TEXT PRIMARY KEY, pocket_id TEXT NOT NULL, kind TEXT NOT NULL, label TEXT NOT NULL, body TEXT NOT NULL, favorite INTEGER NOT NULL, position INTEGER NOT NULL);
            CREATE TABLE scratchpads (pocket_id TEXT PRIMARY KEY, body TEXT NOT NULL);
            CREATE TABLE reference_items (id TEXT PRIMARY KEY, pocket_id TEXT NOT NULL, label TEXT NOT NULL, note TEXT NOT NULL, display_name TEXT NOT NULL, asset TEXT NOT NULL, is_image INTEGER NOT NULL, position INTEGER NOT NULL);
            INSERT INTO pockets VALUES ('\(pocket)', 'Existing pocket');
            INSERT INTO text_items VALUES ('\(item)', '\(pocket)', 'prompt', 'Existing prompt', 'Explain {{topic}}', 0, 0);
            INSERT INTO scratchpads VALUES ('\(pocket)', 'Keep my note');
            PRAGMA user_version = 1;
            """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)
        let loaded = try await LibraryStore(root: folder).load()
        #expect(loaded.pocketID == pocket)
        #expect(loaded.prompts.first?.id == item)
        #expect(loaded.prompts.first?.usesFields == true)
        #expect(loaded.note == "Keep my note")
        let snapshots = try FileManager.default.contentsOfDirectory(at: folder.appending(path: "snapshots"), includingPropertiesForKeys: nil)
        #expect(snapshots.count == 1)
        var backup: OpaquePointer?
        #expect(sqlite3_open_v2(snapshots[0].path, &backup, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(backup, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK)
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 1)
        sqlite3_finalize(statement); sqlite3_close(backup)
    }

    @Test("A newer schema is rejected without changing the database")
    func newerSchema() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "library.sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA user_version = 99; CREATE TABLE future_data (value TEXT); INSERT INTO future_data VALUES ('keep');", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)
        let before = try Data(contentsOf: url)
        await #expect(throws: LibraryStoreError.self) { try await LibraryStore(root: folder).load() }
        #expect(try Data(contentsOf: url) == before)
    }

}
