import AppKit
import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Phase 2 durability")
struct Phase2PersistenceTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "nivlet-phase2-\(UUID().uuidString)")
    }

    @Test("The initial pocket is durable and independent libraries have unique identities")
    func initialPocket() async throws {
        let first = root(), second = root()
        defer { try? FileManager.default.removeItem(at: first); try? FileManager.default.removeItem(at: second) }
        let a = try await LibraryStore(root: first).load()
        #expect(try await LibraryStore(root: first).load() == a)
        #expect(try await LibraryStore(root: second).load().pocketID != a.pocketID)
    }

    @Test("Version-three migration snapshots the existing library before adding recovery")
    func migrationFromCurrentLibrary() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var original = try await store.load()
        original.prompts = [SavedPrompt(label: "Existing", source: "Preserve me ✅")]
        try await store.save(original, revision: 1)
        var db: OpaquePointer?
        try #require(sqlite3_open(folder.appending(path: "library.sqlite").path, &db) == SQLITE_OK)
        let result = sqlite3_exec(db, "DROP TABLE pending_save; PRAGMA user_version = 3", nil, nil, nil)
        sqlite3_close(db)
        #expect(result == SQLITE_OK)
        let reopened = LibraryStore(root: folder)
        #expect(try await reopened.load() == original)
        #expect(try await reopened.recoverableSnapshot() == nil)
        let snapshots = try FileManager.default.contentsOfDirectory(at: folder.appending(path: "snapshots"), includingPropertiesForKeys: nil)
        #expect(snapshots.count == 1)
        try #require(sqlite3_open_v2(snapshots[0].path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 3)
    }

    @Test("An edit during an in-flight save cannot be replaced by the older completion")
    @MainActor
    func editingDuringSave() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        library.note = "Older"
        let saving = Task { await library.flush() }
        await Task.yield()
        library.note = "Newer ✅"
        #expect(await library.flush())
        _ = await saving.value
        #expect(library.saveState == .saved)
        #expect(!library.hasUnsavedChanges)
        #expect(try await LibraryStore(root: folder).load().note == "Newer ✅")
    }

    @Test("Failed and interrupted writes preserve committed data and recover exact pending text",
          arguments: [LibraryStore.CommitFailure.rollback, .diskFull, .interrupted])
    func recoverFailedWrite(failure: LibraryStore.CommitFailure) async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var good = try await store.load()
        good.prompts = [SavedPrompt(label: "Saved", source: "Last good 👩🏽‍💻\r\n")]
        try await store.save(good, revision: 1)
        var pending = good
        pending.prompts[0].source = String(repeating: "Mixed\r\n\nCR\rUnicode ✅\0  ", count: 10_000)
        pending.note = "[x] Keep the failed note\n[ ] Next"
        await store.failNextCommitForTesting(failure)
        do {
            try await store.save(pending, revision: 2)
            Issue.record("Injected write should fail")
        } catch {
            if failure == .diskFull {
                guard case LibraryStoreError.diskFull = error else {
                    Issue.record("Expected real SQLITE_FULL, got \(error)"); return
                }
            }
        }
        let reopened = LibraryStore(root: folder)
        #expect(try await reopened.load() == good)
        #expect(try await reopened.recoverableSnapshot() == pending)
        #expect(try await reopened.save(pending, revision: 1))
        #expect(try await reopened.load() == pending)
        #expect(try await reopened.recoverableSnapshot() == nil)
    }

    @Test("Relaunch shows failed edits with Retry and only reports Saved after a commit")
    @MainActor
    func recoveryPresentation() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        let library = PocketLibrary(root: folder, store: store)
        await library.load()
        library.note = "[ ] Recover me immediately"
        await store.failNextCommitForTesting()
        #expect(await library.flush() == false)
        let reopened = PocketLibrary(root: folder)
        await reopened.load()
        #expect(reopened.isLoaded)
        #expect(reopened.note == library.note)
        #expect(reopened.hasUnsavedChanges)
        #expect(reopened.needsRecoveryReview)
        if case .failed = reopened.saveState {} else { Issue.record("Recovered changes must await review/retry") }
        #expect(await reopened.flush() == false)
        #expect(try await LibraryStore(root: folder).load().note.isEmpty == true)
        #expect(await reopened.retrySaving())
        #expect(reopened.saveState == .saved)
        #expect(!reopened.hasUnsavedChanges)
    }

    @Test("Immediate lifecycle flush commits the latest note before debounce fires")
    @MainActor
    func immediateFlush() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        library.note = "First edit"
        library.note = "Latest edit\r\n[ ] Next ✅"
        #expect(library.saveState == .saving)
        #expect(await library.flush())
        #expect(try await LibraryStore(root: folder).load().note == library.note)
        #expect(library.saveState == .saved)
    }

    @Test("Scratchpad autosaves without a lifecycle flush")
    @MainActor
    func autosave() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        library.note = "Autosaved without an explicit flush"
        // Poll the observable outcome instead of making test success depend on disk speed.
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while library.hasUnsavedChanges, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(library.saveState == .saved)
        #expect(try await LibraryStore(root: folder).load().note == library.note)
    }

    @Test("Rename, duplicate, favourite, group order and repeated Undo survive restart")
    @MainActor
    func promptOperations() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        let a = UUID(), b = UUID(), c = UUID()
        #expect(await library.savePrompt(id: a, label: "A", source: "A body", favorite: true))
        #expect(await library.savePrompt(id: b, label: "B", source: "B body", favorite: false))
        #expect(await library.savePrompt(id: c, label: "C", source: "C body", favorite: true))
        library.movePrompt(id: c, by: -1)
        #expect(ShelfIndex.orderedIDs(.prompts, kit: library, query: "") == [c, a, b])
        #expect(!library.canMovePrompt(id: c, by: -1))
        #expect(!library.canMovePrompt(id: a, by: 1))
        library.duplicate(id: a, tool: .prompts)
        let copy = try #require(library.prompts.first(where: { $0.id != a && $0.label == "A copy" }))
        #expect(copy.isFavorite)
        #expect(copy.source == "A body")
        #expect(await library.savePrompt(id: a, label: "Renamed", source: "New A", favorite: true))
        library.toggleFavorite(id: b, tool: .prompts)
        library.delete(id: a, tool: .prompts)
        library.delete(id: c, tool: .prompts)
        library.note = "A newer note"
        library.undoDelete()
        #expect(library.prompts.contains(where: { $0.id == c }))
        #expect(!library.prompts.contains(where: { $0.id == a }))
        library.undoDelete()
        #expect(library.prompts.contains(where: { $0.id == a && $0.label == "Renamed" }))
        #expect(library.note == "A newer note")
        #expect(await library.flush())
        let loaded = try await LibraryStore(root: folder).load()
        #expect(loaded.prompts == library.prompts)
        #expect(loaded.note == library.note)
    }

    @Test("Blank prompts are rejected without changing the committed library", arguments: ["", " \t\r\n"])
    @MainActor
    func emptyPrompt(body: String) async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        #expect(await library.savePrompt(id: nil, label: "Empty", source: body, favorite: false) == false)
        #expect(library.prompts.isEmpty)
        #expect(!library.hasUnsavedChanges)
    }

    @Test("Stored, reviewed and copied text match exactly with mixed endings and NUL")
    @MainActor
    func storedCopy() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = PocketLibrary(root: folder)
        await library.load()
        let text = "  café e\u{301} 👩🏽‍💻\r\n\nCR\rNULL\0 {{literal}}\n  "
        #expect(await library.savePrompt(id: nil, label: "Copy", source: text, favorite: false))
        let loaded = try await LibraryStore(root: folder).load()
        let reviewed = try #require(loaded.prompts.first?.source)
        let pasteboard = NSPasteboard(name: .init("nivlet-phase2-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        #expect(TextCopier.copy(reviewed, to: pasteboard))
        let copied = try #require(pasteboard.string(forType: .string))
        #expect(Array(copied.utf8) == Array(text.utf8))
    }
}
