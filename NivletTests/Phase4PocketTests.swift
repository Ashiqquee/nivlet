import AppKit
import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Phase 4 pocket workflow")
struct Phase4PocketTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appending(path: "nivlet-phase4-\(UUID().uuidString)") }

    @Test("Similar labels, scratchpads and original bytes remain isolated through switching and restart")
    @MainActor func isolation() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load()
        let a = kit.pocketID; kit.renamePocket("Website")
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Website {{topic}}", favorite: true, usesFields: true))
        kit.note = "Website scratchpad ✅\r\n"
        let source = folder.appending(path: "Website.txt")
        try Data("website original".utf8).write(to: source)
        await kit.importFiles([source]); let ref = try #require(kit.references.first)
        kit.updateReference(id: ref.id, note: "Website note")
        let b = try #require(kit.createPocket("Writing"))
        #expect(await kit.switchPocket(to: b)); #expect(kit.note.isEmpty); #expect(kit.references.isEmpty)
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Writing body", favorite: false))
        kit.note = "Writing scratchpad"
        #expect(await kit.switchPocket(to: a)); #expect(kit.note == "Website scratchpad ✅\r\n")
        #expect(kit.prompts.first?.source == "Website {{topic}}"); #expect(kit.references.first?.note == "Website note")
        try FileManager.default.removeItem(at: source)
        #expect(await kit.flush())
        let reopened = PocketLibrary(root: folder); await reopened.load()
        #expect(reopened.pocketID == a); #expect(reopened.pockets.count == 2)
        #expect(try Data(contentsOf: try #require(reopened.references.first).originalURL) == Data("website original".utf8))
        #expect(await reopened.switchPocket(to: b)); #expect(reopened.prompts.first?.source == "Writing body")
        #expect(reopened.note == "Writing scratchpad"); #expect(reopened.references.isEmpty)
    }

    @Test("A failed flush prevents switching and complete ownership recovers on relaunch", arguments: [LibraryStore.CommitFailure.rollback, .diskFull, .interrupted])
    @MainActor func failedSwitch(failure: LibraryStore.CommitFailure) async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder); let kit = PocketLibrary(root: folder, store: store); await kit.load()
        let a = kit.pocketID; let b = try #require(kit.createPocket("Writing")); #expect(await kit.flush())
        kit.note = String(repeating: "Unsaved ✅", count: 1500)
        await store.failNextCommitForTesting(failure)
        #expect(await kit.switchPocket(to: b) == false); #expect(kit.pocketID == a); #expect(kit.hasUnsavedChanges)
        let recovered = PocketLibrary(root: folder); await recovered.load()
        #expect(recovered.needsRecoveryReview); #expect(recovered.pockets.count == 2); #expect(recovered.note == kit.note)
        #expect(await recovered.switchPocket(to: b) == false)
        #expect(await recovered.retrySaving()); #expect(await recovered.switchPocket(to: b)); #expect(recovered.note.isEmpty)
    }

    @Test("Pocket view, selection, unsubmitted editor and filled values remain scoped")
    @MainActor func viewState() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "{{topic}}", favorite: false, usesFields: true))
        let prompt = try #require(kit.prompts.first); let b = try #require(kit.createPocket("Writing"))
        let model = PanelModel(pasteboard: .withUniqueName()); model.selection = prompt.id
        model.fieldValues[prompt.id] = ["topic": "Website only"]
        model.edit(prompt); let draft = try #require(model.draft); draft.text = "Unsubmitted website edit"; draft.hasChanges = true
        #expect(await model.switchPocket(to: b, kit: kit)); #expect(model.draft == nil); #expect(model.inspector == nil); #expect(model.hasUnsubmittedDrafts)
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "{{topic}}", favorite: false, usesFields: true))
        let writing = try #require(kit.prompts.first); #expect(model.fieldValues[writing.id] == nil)
        model.tool = .references
        #expect(await model.switchPocket(to: a, kit: kit)); #expect(model.draft === draft)
        #expect(model.draft?.text == "Unsubmitted website edit"); #expect(model.selection == prompt.id)
        #expect(model.fieldValues[prompt.id]?["topic"] == "Website only")
        #expect(await model.switchPocket(to: b, kit: kit)); #expect(model.tool == .references)
        #expect(kit.pockets.first { $0.pocketID == a }?.prompts.first?.source == "{{topic}}")
        model.discardAllDrafts(); #expect(!model.hasUnsubmittedDrafts)
        #expect(await model.switchPocket(to: a, kit: kit)); #expect(model.draft == nil)
    }

    @Test("Discarded cached drafts cannot reappear, and search preserves an unsubmitted destination editor")
    @MainActor func safeDraftNavigation() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Website body", favorite: false))
        let item = try #require(kit.prompts.first); let b = try #require(kit.createPocket("Writing"))
        let model = PanelModel(pasteboard: .withUniqueName()); model.edit(item)
        model.draft?.text = "Unsubmitted source"; model.draft?.hasChanges = true
        #expect(await model.switchPocket(to: b, kit: kit))
        let result = try #require(kit.search("Website body", scope: .all).first)
        await model.openSearchResult(result, kit: kit)
        #expect(kit.pocketID == a); #expect(model.inspector == .editor)
        #expect(model.draft?.text == "Unsubmitted source"); #expect(model.hasUnsubmittedDrafts)
        model.discardDraft(); #expect(!model.hasUnsubmittedDrafts)
        #expect(await model.switchPocket(to: b, kit: kit)); #expect(await model.switchPocket(to: a, kit: kit))
        #expect(model.draft == nil); #expect(model.inspector == nil)
        #expect(kit.prompts.first?.source == "Website body")
    }

    @Test("A failed pocket deletion journals live and trash ownership together without losing originals")
    @MainActor func interruptedTrash() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder); let kit = PocketLibrary(root: folder, store: store); await kit.load()
        let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Website", favorite: false))
        let b = try #require(kit.createPocket("Writing")); #expect(await kit.flush())
        await store.failNextCommitForTesting()
        #expect(await kit.deletePocket()); #expect(kit.pocketID == b)
        #expect(kit.hasUnsavedChanges); #expect(kit.recoverablePockets().map(\.id) == [a])
        let disk = try await LibraryStore(root: folder).loadCollection()
        #expect(disk.pockets.count == 2); #expect(disk.trash.isEmpty)
        let recovered = PocketLibrary(root: folder); await recovered.load()
        #expect(recovered.needsRecoveryReview); #expect(recovered.pocketID == b)
        #expect(recovered.recoverablePockets().map(\.id) == [a]); #expect(await recovered.retrySaving())
        #expect(recovered.restorePocket(id: a)); #expect(await recovered.switchPocket(to: a))
        #expect(recovered.prompts.first?.source == "Website")
    }

    @Test("Search includes labels, reviewed bodies and notes, excludes hidden files, scratchpad and trash")
    @MainActor func search() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID; kit.renamePocket("Website")
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Café layout", favorite: false))
        let source = folder.appending(path: "hidden-secret.txt"); try Data("hidden content secret".utf8).write(to: source)
        await kit.importFiles([source]); let ref = try #require(kit.references.first)
        kit.renameReference(id: ref.id, label: "Layout reference"); kit.updateReference(id: ref.id, note: "Contrast REVIEW")
        kit.note = "scratchpad-only"
        let b = try #require(kit.createPocket("Writing")); #expect(await kit.switchPocket(to: b))
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Writing body", favorite: false))
        #expect(kit.search("review", scope: .active).count == 1)
        #expect(kit.search("review", scope: .all).count == 3)
        #expect(kit.search("cafe", scope: .all).first?.pocketID == a)
        #expect(kit.search("hidden", scope: .all).isEmpty); #expect(kit.search("secret", scope: .all).isEmpty)
        #expect(kit.search("scratchpad-only", scope: .all).isEmpty); #expect(kit.search("  ", scope: .all).isEmpty)
        let model = PanelModel(pasteboard: .withUniqueName()); model.searchScope = .all; model.query = "cafe"
        let result = try #require(kit.search(model.query, scope: model.searchScope).first)
        await model.openSearchResult(result, kit: kit)
        #expect(kit.pocketID == a); #expect(model.inspector == .prompt(result.id)); #expect(model.query.isEmpty)
        #expect(await kit.deletePocket()); #expect(kit.search("cafe", scope: .all).isEmpty)
    }

    @Test("Pocket duplicates receive new independent identities while shared original bytes survive deletion")
    @MainActor func duplicateAndAssets() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "{{topic}}", favorite: true, usesFields: true))
        let source = folder.appending(path: "Original.txt"); try Data("shared original ✅".utf8).write(to: source)
        await kit.importFiles([source]); let original = try #require(kit.references.first)
        kit.updateReference(id: original.id, note: "Original note"); kit.note = "Original scratchpad"
        let b = try #require(kit.duplicatePocket()); #expect(await kit.switchPocket(to: b))
        let copy = try #require(kit.references.first)
        #expect(copy.id != original.id); #expect(copy.originalURL == original.originalURL); #expect(copy.displayName == original.displayName)
        #expect(kit.prompts.first?.id != kit.pockets.first?.prompts.first?.id)
        kit.updateReference(id: copy.id, note: "Independent note"); kit.renameReference(id: copy.id, label: "Independent label")
        kit.note = "Independent scratchpad"
        #expect(kit.assetReferenceCounts[original.originalURL] == 2)
        #expect(await kit.switchPocket(to: a)); #expect(kit.references.first?.note == "Original note"); #expect(kit.note == "Original scratchpad")
        kit.delete(id: original.id, tool: .references)
        #expect(kit.assetReferenceCounts[original.originalURL] == 2) // live copy + in-session Undo
        #expect(await kit.flush()); try FileManager.default.removeItem(at: source)
        let reopened = PocketLibrary(root: folder); await reopened.load(); #expect(await reopened.switchPocket(to: b))
        #expect(reopened.references.first?.note == "Independent note")
        #expect(try Data(contentsOf: copy.originalURL) == Data("shared original ✅".utf8))
    }

    @Test("Explicit moves preserve independent metadata and clear moved filled values")
    @MainActor func moves() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "{{topic}}", favorite: false, usesFields: true))
        let prompt = try #require(kit.prompts.first); let b = try #require(kit.createPocket("Writing"))
        kit.duplicate(id: prompt.id, tool: .prompts); let copy = try #require(kit.prompts.last)
        let model = PanelModel(pasteboard: .withUniqueName()); model.inspector = .prompt(prompt.id)
        model.fieldValues[prompt.id] = ["topic": "Website only"]; model.moveRequest = .init(id: prompt.id, tool: .prompts)
        model.finishMove(to: b, kit: kit)
        #expect(model.inspector == nil); #expect(model.fieldValues[prompt.id] == nil)
        #expect(kit.prompts.map(\.id) == [copy.id]); #expect(!kit.moveItem(id: copy.id, tool: .prompts, to: UUID()))
        let source = folder.appending(path: "Original.txt"); try Data("original".utf8).write(to: source)
        await kit.importFiles([source]); let ref = try #require(kit.references.first)
        kit.updateReference(id: ref.id, note: "Move this note"); kit.duplicate(id: ref.id, tool: .references)
        #expect(kit.moveItem(id: ref.id, tool: .references, to: b)); #expect(kit.references.count == 1)
        #expect(await kit.switchPocket(to: b)); #expect(kit.prompts.map(\.id) == [prompt.id]); #expect(kit.references.first?.note == "Move this note")
        kit.updateReference(id: ref.id, note: "Destination change")
        #expect(await kit.switchPocket(to: a)); #expect(kit.references.first?.note == "Move this note")
        #expect(await kit.flush())
    }

    @Test("Seven-day trash restores the entire kit and original bytes after immediate restart")
    @MainActor func trashRestore() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID; kit.renamePocket("Website")
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "Exact body ✅", favorite: true))
        let source = folder.appending(path: "Original.txt"); let bytes = Data("original ✅".utf8); try bytes.write(to: source)
        await kit.importFiles([source]); let ref = try #require(kit.references.first); kit.note = "[ ] Recover this\r\n"
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(await kit.deletePocket(now: now)); #expect(kit.pocketID != a); #expect(kit.pockets.count == 1)
        #expect(kit.assetReferenceCounts[ref.originalURL] == 1)
        try FileManager.default.removeItem(at: source)
        let reopened = PocketLibrary(root: folder); await reopened.load()
        #expect(reopened.recoverablePockets(at: now).map(\.id) == [a])
        #expect(reopened.restorePocket(id: a, now: now.addingTimeInterval(7 * 86400 - 1)))
        #expect(await reopened.switchPocket(to: a)); #expect(reopened.note == "[ ] Recover this\r\n")
        #expect(reopened.prompts.first?.source == "Exact body ✅"); #expect(reopened.references.first?.id == ref.id)
        #expect(try Data(contentsOf: ref.originalURL) == bytes)
        #expect(await reopened.deletePocket(now: now))
        #expect(!reopened.restorePocket(id: a, now: now.addingTimeInterval(7 * 86400)))
        #expect(reopened.recoverablePockets(at: now.addingTimeInterval(7 * 86400)).isEmpty)
        #expect(FileManager.default.fileExists(atPath: ref.originalURL.path)) // GC deferred to Phase 5.
    }

    @Test("Item Undo stays with its owner and cannot change the other pocket's notes")
    @MainActor func scopedUndo() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "First", source: "A", favorite: false))
        let item = try #require(kit.prompts.first); kit.delete(id: item.id, tool: .prompts)
        let b = try #require(kit.createPocket("Writing")); #expect(await kit.switchPocket(to: b))
        kit.note = "Writing only"; #expect(!kit.canUndoDelete); kit.undoDelete(); #expect(kit.prompts.isEmpty)
        #expect(await kit.switchPocket(to: a)); #expect(kit.canUndoDelete); kit.note = "New website note"; kit.undoDelete()
        #expect(kit.prompts.map(\.id) == [item.id]); #expect(kit.note == "New website note")
        #expect(await kit.switchPocket(to: b)); #expect(kit.note == "Writing only")
    }

    @Test("Pocket and reference ordering and favourites survive restart")
    @MainActor func ordering() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        let b = try #require(kit.createPocket("Writing")); let c = try #require(kit.createPocket("Research"))
        kit.reorderPocket(id: c, by: -1); #expect(kit.pockets.map(\.id) == [a, c, b])
        let source = folder.appending(path: "Same.txt"); try Data("original".utf8).write(to: source)
        await kit.importFiles([source, source, source]); let ids = kit.references.map(\.id)
        kit.toggleFavorite(id: ids[1], tool: .references)
        kit.moveReference(id: ids[2], by: -1)
        #expect(ShelfIndex.references(kit: kit, query: "").map(\.id) == [ids[1], ids[2], ids[0]])
        #expect(await kit.flush())
        let reopened = PocketLibrary(root: folder); await reopened.load()
        #expect(reopened.pockets.map(\.id) == [a, c, b])
        #expect(ShelfIndex.references(kit: reopened, query: "").map(\.id) == [ids[1], ids[2], ids[0]])
        #expect(reopened.references.allSatisfy { $0.byteCount == 8 })
    }

    @Test("Each pocket restores its saved tool, search scope and selection after restart")
    @MainActor func savedView() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load(); let a = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "Review", source: "A", favorite: false))
        let id = try #require(kit.prompts.first?.id)
        kit.updateView(PocketViewBookmark(tool: .prompts, selection: id, query: "Review", scope: .all))
        let b = try #require(kit.createPocket("Writing")); #expect(await kit.switchPocket(to: b))
        kit.updateView(PocketViewBookmark(tool: .notes, query: "", scope: .active)); kit.note = "Persist immediately"
        #expect(await kit.flush())
        let reopened = PocketLibrary(root: folder); await reopened.load()
        let model = PanelModel(pasteboard: .withUniqueName()); model.restorePocketView(reopened)
        #expect(model.tool == .notes); #expect(reopened.note == "Persist immediately")
        #expect(await model.switchPocket(to: a, kit: reopened))
        #expect(model.tool == .prompts); #expect(model.selection == id); #expect(model.query == "Review"); #expect(model.searchScope == .all)
    }

    @Test("A legacy single-pocket client cannot flatten a live or trashed multi-pocket library")
    func refusesFlattening() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder); let a = try await store.load(); var b = LibrarySnapshot.empty; b.pocketName = "Writing"
        let collection = PocketCollection(pockets: [a, b], activePocketID: b.pocketID)
        #expect(try await store.saveCollection(collection, revision: 1))
        await #expect(throws: LibraryStoreError.self) { try await store.save(a, revision: 2) }
        #expect(try await store.loadCollection() == collection)
        var invalid = collection; invalid.pockets[1].pocketID = a.pocketID
        await #expect(throws: LibraryStoreError.self) { try await store.saveCollection(invalid, revision: 3) }
        #expect(try await store.loadCollection() == collection)
    }

    @Test("Schema-four migration preserves exact legacy recovery, IDs and original filenames")
    func migration() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pocket = LibrarySnapshot.empty
        var pending = pocket; pending.note = "Recovered old journal ✅\r\n"
        let json = String(decoding: try JSONEncoder().encode(pending), as: UTF8.self).replacingOccurrences(of: "'", with: "''")
        var db: OpaquePointer?; try #require(sqlite3_open(folder.appending(path: "library.sqlite").path, &db) == SQLITE_OK)
        let sql = """
        CREATE TABLE pockets (id TEXT PRIMARY KEY,name TEXT NOT NULL);
        CREATE TABLE text_items (id TEXT PRIMARY KEY,pocket_id TEXT NOT NULL,kind TEXT NOT NULL,label TEXT NOT NULL,body TEXT NOT NULL,favorite INTEGER NOT NULL,position INTEGER NOT NULL,uses_fields INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE scratchpads (pocket_id TEXT PRIMARY KEY,body TEXT NOT NULL);
        CREATE TABLE reference_items (id TEXT PRIMARY KEY,pocket_id TEXT NOT NULL,label TEXT NOT NULL,note TEXT NOT NULL,display_name TEXT NOT NULL,asset TEXT NOT NULL,is_image INTEGER NOT NULL,position INTEGER NOT NULL);
        CREATE TABLE pending_save (id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL);
        INSERT INTO pockets VALUES ('\(pocket.pocketID)', 'My pocket');
        INSERT INTO scratchpads VALUES ('\(pocket.pocketID)', 'Last good');
        INSERT INTO pending_save VALUES (1, '\(json)');
        PRAGMA user_version = 4;
        """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK); sqlite3_close(db)
        let store = LibraryStore(root: folder)
        #expect(try await store.loadCollection().pockets.first?.note == "Last good")
        #expect(try await store.recoverableCollection()?.pockets.first?.note == pending.note)
        #expect(try await store.load().pocketID == pocket.pocketID)
        let backups = try FileManager.default.contentsOfDirectory(at: folder.appending(path: "snapshots"), includingPropertiesForKeys: nil)
        #expect(backups.count == 1)
        #expect(try await store.saveCollection(PocketCollection(pocket: pending), revision: 1))
        #expect(try await store.recoverableCollection() == nil)
    }
}
