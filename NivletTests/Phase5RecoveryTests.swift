import CryptoKit
import Foundation
import SQLite3
import Testing
@testable import Nivlet

@Suite("Phase 5 portable ownership and recovery")
struct Phase5RecoveryTests {
    private func base() -> URL { FileManager.default.temporaryDirectory.appending(path: "nivlet-phase5-\(UUID().uuidString)") }
    private func makeFolder(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    private func fixture(_ base: URL) async throws -> (LibraryStore, PocketCollection) {
        try makeFolder(base)
        let store = LibraryStore(root: base.appending(path: "library"))
        var a = try await store.load(); a.pocketName = "Website ✅"
        a.prompts = [SavedPrompt(label: "Review", source: "Keep CRLF\r\nCR\rLF\n  👩🏽‍💻\0", isFavorite: true),
                     SavedPrompt(label: "Fill", source: #"Review {{page}}. {{page}}. \{\{literal\}\}."#, usesFields: true)]
        a.note = "[x] Complete ✅\r\n[ ] Next task\nKeep spaces  "
        a.view = PocketViewBookmark(tool: .notes, query: "private view", scope: .all)
        let bytes = [Data("Original text ✅\r\n".utf8), Data([0, 255, 127, 128, 0, 1]),
                     Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!]
        for (i, data) in bytes.enumerated() {
            let source = base.appending(path: ["Original ✅.txt", "Data.bin", "Pixel.png"][i]); try data.write(to: source)
            var reference = try await store.importFile(source); reference.note = "Separate note \(i) ✅"; reference.isFavorite = i == 1
            a.references.append(reference)
        }
        var b = LibrarySnapshot.empty; b.pocketName = "Writing"
        b.prompts = [SavedPrompt(label: "Review", source: "Writing body")]; b.note = "[ ] Writing only"
        let original = a.references[0]
        b.references = [ReferenceItem(id: UUID(), label: "Same bytes, own label", note: "Independent note", displayName: "Different name.md",
                                    originalURL: original.originalURL, isImage: false, byteCount: original.byteCount)]
        let collection = PocketCollection(pockets: [a,b], activePocketID: b.pocketID)
        #expect(try await store.saveCollection(collection, revision: 1))
        return (store, collection)
    }
    private func archive(_ base: URL) async throws -> (URL, PocketArchiveManifest, PocketCollection) {
        let (store, collection) = try await fixture(base)
        let preview = try await store.prepareExport(collection.pockets)
        let url = base.appending(path: "Library.nivlet")
        try await store.exportArchive(preview.id, to: url); try await store.closeArchive(preview.id)
        return (url, preview.manifest, collection)
    }
    private func compare(_ original: [LibrarySnapshot], _ restored: [LibrarySnapshot]) throws {
        #expect(restored.count == original.count)
        for (a,b) in zip(original, restored) {
            #expect(a.pocketID != b.pocketID); #expect(a.pocketName == b.pocketName); #expect(a.note == b.note); #expect(b.view == nil)
            #expect(a.prompts.count == b.prompts.count); #expect(a.references.count == b.references.count)
            for (x,y) in zip(a.prompts,b.prompts) {
                #expect(x.id != y.id); #expect(x.label == y.label); #expect(x.source == y.source)
                #expect(x.isFavorite == y.isFavorite); #expect(x.usesFields == y.usesFields)
            }
            for (x,y) in zip(a.references,b.references) {
                #expect(x.id != y.id); #expect(x.label == y.label); #expect(x.note == y.note); #expect(x.displayName == y.displayName)
                #expect(x.isFavorite == y.isFavorite); #expect(x.byteCount == y.byteCount); #expect(x.isImage == y.isImage)
                #expect(try Data(contentsOf: x.originalURL) == Data(contentsOf: y.originalURL))
                #expect(try FileHandoff.sha256(of: y.originalURL) == x.originalURL.deletingLastPathComponent().lastPathComponent)
                #expect(!FileManager.default.isWritableFile(atPath: y.originalURL.path))
            }
        }
    }

    @Test("A complete library round-trips to a clean installation with independent IDs and exact originals")
    func roundTrip() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, manifest, collection) = try await archive(folder)
        let clean = LibraryStore(root: folder.appending(path: "clean")); let empty = try await clean.loadCollection()
        let preview = try await clean.prepareRestore(from: url)
        #expect(preview.manifest == manifest); #expect(preview.promptCount == 3); #expect(preview.referenceCount == 4)
        #expect(try await clean.loadCollection() == empty)
        let restored = try await clean.commitRestore(preview.id, revision: 1)
        #expect(restored.activePocketID == empty.activePocketID)
        try compare(collection.pockets, Array(restored.pockets.dropFirst()))
        let reopened = try await LibraryStore(root: folder.appending(path: "clean")).loadCollection()
        #expect(reopened == restored)
        let second = try await clean.prepareRestore(from: url)
        let repeated = try await clean.commitRestore(second.id, revision: 2)
        #expect(repeated.pockets.count == 5)
        let ids = repeated.pockets.flatMap { $0.prompts.map(\.id) + $0.references.map(\.id) }
        #expect(Set(ids).count == ids.count)
        #expect(Array(repeated.pockets.prefix(3)) == restored.pockets)
        try compare(collection.pockets, Array(repeated.pockets.suffix(2)))
    }

    @Test("One-pocket export excludes other pockets, trash, entitlement, drafts, internal paths and device state")
    func exclusions() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (store, collection) = try await fixture(folder)
        var saved = collection
        saved.trash = [TrashedPocket(pocket: .empty, deletedAt: .now)]
        #expect(try await store.saveCollection(saved, revision: 2))
        let preview = try await store.prepareExport([collection.pockets[0]])
        #expect(preview.names == ["Website ✅"]); #expect(preview.promptCount == 2); #expect(preview.manifest.assets.count == 3)
        let json = String(decoding: try JSONEncoder().encode(preview.manifest), as: UTF8.self)
        for excluded in ["originalURL", "activePocketID", "private view", "view_state", "entitlement", "licence", folder.path] { #expect(!json.contains(excluded)) }
        let destination = folder.appending(path: "One.nivlet")
        try await store.exportArchive(preview.id, to: destination); try await store.closeArchive(preview.id)
        let clean = LibraryStore(root: folder.appending(path: "clean")); _ = try await clean.load()
        let restore = try await clean.prepareRestore(from: destination)
        let copied = try await clean.commitRestore(restore.id, revision: 1)
        try compare([collection.pockets[0]], Array(copied.pockets.dropFirst()))
    }

    @Test("Export uses one pinned snapshot and failure before publish preserves an existing destination")
    func consistentExport() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (store, original) = try await fixture(folder)
        let preview = try await store.prepareExport(original.pockets)
        var newer = original; newer.pockets[0].note = "Newer note after preview"; newer.pockets[0].references = []
        #expect(try await store.saveCollection(newer, revision: 2))
        let destination = folder.appending(path: "Existing.nivlet"); let existing = Data("Last good export".utf8); try existing.write(to: destination)
        await store.failNextArchiveForTesting(.exportBeforePublish)
        await #expect(throws: LibraryStoreError.self) { try await store.exportArchive(preview.id, to: destination) }
        #expect(try Data(contentsOf: destination) == existing)
        try await store.exportArchive(preview.id, to: destination)
        let clean = LibraryStore(root: folder.appending(path: "clean")); _ = try await clean.load()
        let restore = try await clean.prepareRestore(from: destination)
        let result = try await clean.commitRestore(restore.id, revision: 1)
        try compare(original.pockets, Array(result.pockets.dropFirst()))
        #expect(try await store.loadCollection() == newer)
        try await store.closeArchive(preview.id)
        #expect(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).allSatisfy { !$0.lastPathComponent.hasSuffix(".partial") })
    }

    @Test("Failed metadata restore leaves last-good data and recovery journal unchanged, including after restart",
          arguments: [LibraryStore.CommitFailure.rollback, .diskFull, .interrupted])
    func atomicFailure(failure: LibraryStore.CommitFailure) async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, _) = try await archive(folder)
        let destination = folder.appending(path: "destination")
        let store = LibraryStore(root: destination); var original = try await store.loadCollection()
        original.pockets[0].note = "Existing work stays here"; #expect(try await store.saveCollection(original, revision: 1))
        let preview = try await store.prepareRestore(from: url)
        // Force real SQLite page growth for SQLITE_FULL without filling the disk.
        var large = preview.manifest; large.pockets[0].scratchpad = String(repeating: "Large ✅", count: 200_000)
        let largeURL = folder.appending(path: "Large.nivlet"); try writeFixture(large, originals: folder.appending(path: "library"), to: largeURL)
        try await store.closeArchive(preview.id)
        let candidate = try await store.prepareRestore(from: largeURL)
        await store.failNextCommitForTesting(failure)
        await #expect(throws: LibraryStoreError.self) { try await store.commitRestore(candidate.id, revision: 2) }
        #expect(try await store.loadCollection() == original); #expect(try await store.recoverableCollection() == nil)
        for var lease in try ArchiveLeases.readAll(root: destination) {
            lease.ownerPID = Int32.max; try ArchiveLeases.write(lease, root: destination)
        }
        let reopened = LibraryStore(root: destination)
        #expect(try await reopened.loadCollection() == original); try await reopened.reconcileInterruptedArchives()
        #expect(try await reopened.recoverableCollection() == nil)
        let retry = try await reopened.prepareRestore(from: url)
        #expect(try await reopened.commitRestore(retry.id, revision: 1).pockets.count == 3)
    }

    @Test("Interruption after asset placement exposes no pockets and retry uses the verified placed bytes")
    func placementFailure() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, original) = try await archive(folder)
        let store = LibraryStore(root: folder.appending(path: "clean")); let before = try await store.loadCollection()
        let preview = try await store.prepareRestore(from: url)
        await store.failNextArchiveForTesting(.restoreAfterPlacement)
        await #expect(throws: LibraryStoreError.self) { try await store.commitRestore(preview.id, revision: 1) }
        #expect(try await store.loadCollection() == before); #expect(try await store.recoverableCollection() == nil)
        let retry = try await store.commitRestore(preview.id, revision: 1)
        try compare(original.pockets, Array(retry.pockets.dropFirst()))
    }

    @Test("Cancel and interrupted-preview reconciliation leave content unchanged and release staging/pins")
    func cancellation() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, _) = try await archive(folder)
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean"))
        let before = try await store.loadCollection()
        let task = Task { try await store.prepareRestore(from: url) }; task.cancel()
        do {
            let preview = try await task.value
            try await store.closeArchive(preview.id)
        } catch { #expect(error is CancellationError) }
        #expect(try await store.loadCollection() == before)
        #expect(try ArchiveLeases.readAll(root: root).isEmpty)
        let preview = try await store.prepareRestore(from: url)
        let stage = root.appending(path: "archive-staging/\(preview.id)")
        #expect(FileManager.default.fileExists(atPath: stage.path))
        for var lease in try ArchiveLeases.readAll(root: root) {
            lease.ownerPID = Int32.max; try ArchiveLeases.write(lease, root: root)
        }
        let reopened = LibraryStore(root: root); try await reopened.reconcileInterruptedArchives()
        #expect(!FileManager.default.fileExists(atPath: stage.path)); #expect(try ArchiveLeases.readAll(root: root).isEmpty)
        #expect(try await reopened.loadCollection() == before)
    }

    private func writeFixture(_ manifest: PocketArchiveManifest, originals: URL, to url: URL,
                              frame: ((Int, inout Data, inout UInt8, inout UInt64, inout Data) -> Void)? = nil) throws {
        let metadata = try JSONEncoder().encode(manifest)
        var bytes = ArchiveDisk.magic + ArchiveDisk.number(UInt64(metadata.count)) + metadata
        for (index, asset) in manifest.assets.enumerated() {
            var path = Data(asset.archivePath.utf8), kind: UInt8 = 0, size = asset.byteCount
            var content = (try? Data(contentsOf: originals.appending(path: asset.path))) ?? Data()
            frame?(index, &path, &kind, &size, &content)
            bytes += Data([kind]) + ArchiveDisk.number(UInt64(path.count)) + path + ArchiveDisk.number(size) + content
        }
        try bytes.write(to: url)
    }

    @Test("Hostile manifests fail without changing destination data", arguments: ["version", "traversal", "absolute", "duplicateAsset", "duplicatePocket", "duplicateItem", "unknownDigest", "malformedTemplate", "emptyName", "assetLimit", "overflow"])
    func hostileManifest(kind: String) async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (_, original, _) = try await archive(folder); var manifest = original
        switch kind {
        case "version": manifest.formatVersion = 99
        case "traversal": manifest.assets[0].archivePath = "../../escape"
        case "absolute": manifest.assets[0].archivePath = "/tmp/nivlet-escape"
        case "duplicateAsset": manifest.assets.append(manifest.assets[0])
        case "duplicatePocket": manifest.pockets.append(manifest.pockets[0])
        case "duplicateItem": manifest.pockets[1].prompts.append(manifest.pockets[0].prompts[0])
        case "unknownDigest": manifest.pockets[0].references[0].digest = String(repeating: "a", count: 64)
        case "malformedTemplate": manifest.pockets[0].prompts[1].source = "{{ bad }}"
        case "emptyName": manifest.pockets[0].name = " \n"
        case "assetLimit": manifest.assets[0].byteCount = 2_000_000_001
        default: manifest.assets[0].byteCount = UInt64.max
        }
        let url = folder.appending(path: "Hostile.nivlet"); try writeFixture(manifest, originals: folder.appending(path: "library"), to: url)
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean"))
        let before = try await store.loadCollection()
        await #expect(throws: PocketArchiveError.self) { try await store.prepareRestore(from: url) }
        #expect(try await store.loadCollection() == before); #expect(try await store.recoverableCollection() == nil)
        #expect(try ArchiveLeases.readAll(root: root).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "escape").path))
    }

    @Test("Hostile frames, symlink kinds, duplicate paths, truncation and tampered bytes cannot escape staging",
          arguments: ["traversal", "absolute", "backslash", "nul", "invalidUTF8", "symlink", "duplicate", "size", "tamper", "truncate", "trailing", "zip", "json"])
    func hostileFrame(kind: String) async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (_, manifest, _) = try await archive(folder)
        let url = folder.appending(path: "Hostile.nivlet")
        try writeFixture(manifest, originals: folder.appending(path: "library"), to: url) { index, path, type, size, content in
            guard index == 0 || kind == "duplicate" else { return }
            switch kind {
            case "traversal": path = Data("../escape".utf8)
            case "absolute": path = Data("/tmp/escape".utf8)
            case "backslash": path = Data("..\\escape".utf8)
            case "nul": path = Data([0])
            case "invalidUTF8": path = Data([255])
            case "symlink": type = 2
            case "duplicate": path = Data(manifest.assets[0].path.utf8)
            case "size": size = UInt64.max
            case "tamper": if !content.isEmpty { content[0] ^= 255 }
            default: break
            }
        }
        var data = try Data(contentsOf: url)
        if kind == "truncate" { data.removeLast() }
        if kind == "trailing" { data.append(0) }
        if kind == "zip" { data = Data([0x50,0x4b,0x03,0x04]) + Data(repeating: 0, count: 1024) }
        if kind == "json" { data = ArchiveDisk.magic + ArchiveDisk.number(1) + Data("{".utf8) }
        try data.write(to: url)
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean"))
        let before = try await store.loadCollection()
        await #expect(throws: PocketArchiveError.self) { try await store.prepareRestore(from: url) }
        #expect(try await store.loadCollection() == before); #expect(try ArchiveLeases.readAll(root: root).isEmpty)
        let stage = root.appending(path: "archive-staging")
        if FileManager.default.fileExists(atPath: stage.path) { #expect(try FileManager.default.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil).isEmpty) }
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "escape").path))
    }

    @Test("Manifest, total byte, item and count bounds reject before commit", arguments: ["manifest", "total", "assets", "pockets", "items"])
    func limits(kind: String) async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, _) = try await archive(folder)
        var limits = PocketArchiveLimits()
        switch kind { case "manifest": limits.manifestBytes = 20; case "total": limits.totalBytes = 5; case "assets": limits.assets = 1; case "pockets": limits.pockets = 1; default: limits.items = 1 }
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean"), archiveIO: PocketArchiveIO(root: folder.appending(path: "clean"), limits: limits))
        let before = try await store.loadCollection()
        await #expect(throws: PocketArchiveError.self) { try await store.prepareRestore(from: url) }
        #expect(try await store.loadCollection() == before); #expect(try ArchiveLeases.readAll(root: root).isEmpty)
        #expect(throws: PocketArchiveError.self) { try ArchiveDisk.checkSpace(at: root, bytes: UInt64.max) }
    }

    @Test("A relocated recovery copy rebases pending originals without reading or writing the old root")
    @MainActor func relocatedPending() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (store, original) = try await fixture(folder)
        var pending = original; pending.pockets[0].note = "Recovered pending text ✅"
        await store.failNextCommitForTesting()
        await #expect(throws: LibraryStoreError.self) { try await store.saveCollection(pending, revision: 2) }
        let copiedRoot = folder.appending(path: "relocated")
        try FileManager.default.copyItem(at: folder.appending(path: "library"), to: copiedRoot)
        // Taking the original root out of reach proves recovery uses the copy.
        try FileManager.default.moveItem(at: folder.appending(path: "library"), to: folder.appending(path: "preserved-old-root"))
        let kit = PocketLibrary(root: copiedRoot); await kit.load()
        #expect(kit.isLoaded); #expect(kit.needsRecoveryReview)
        #expect(kit.pockets[0].note == "Recovered pending text ✅")
        for reference in kit.pockets.flatMap(\.references) {
            #expect(reference.originalURL.path.hasPrefix(copiedRoot.path + "/assets/"))
            #expect(try FileHandoff.sha256(of: reference.originalURL) == reference.originalURL.deletingLastPathComponent().lastPathComponent)
        }
        #expect(await kit.retrySaving()); #expect(!kit.needsRecoveryReview)
        let saved = try await LibraryStore(root: copiedRoot).loadCollection()
        #expect(saved.pockets[0].note == "Recovered pending text ✅")
    }

    @Test("Source and destination symlinks and internal library paths are refused")
    func fileBoundaries() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, collection) = try await archive(folder)
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean")); _ = try await store.load()
        let alias = folder.appending(path: "Alias.nivlet"); try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: url)
        await #expect(throws: PocketArchiveError.self) { try await store.prepareRestore(from: alias) }
        await #expect(throws: PocketArchiveError.self) { try await store.prepareRestore(from: URL(string: "https://example.com/kit.nivlet")!) }
        let export = try await store.prepareExport([try await store.load()])
        await #expect(throws: PocketArchiveError.self) { try await store.exportArchive(export.id, to: root.appending(path: "library.sqlite")) }
        await #expect(throws: PocketArchiveError.self) { try await store.exportArchive(export.id, to: alias) }
        try await store.closeArchive(export.id)
        let preview = try await store.prepareRestore(from: url)
        let outside = folder.appending(path: "outside"); try makeFolder(outside)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "assets"), withDestinationURL: outside)
        await #expect(throws: PocketArchiveError.self) { try await store.commitRestore(preview.id, revision: 1) }
        #expect(try FileManager.default.contentsOfDirectory(at: outside, includingPropertiesForKeys: nil).isEmpty)
        #expect(try await store.loadCollection().pockets.count == 1)
        #expect(collection.pockets.count == 2)
    }

    @Test("Staged or existing-asset corruption is rechecked at commit")
    func commitIntegrity() async throws {
        let folder = base(); defer { try? FileManager.default.removeItem(at: folder) }
        let (url, _, _) = try await archive(folder)
        let root = folder.appending(path: "clean"), store = LibraryStore(root: folder.appending(path: "clean")); let before = try await store.loadCollection()
        let preview = try await store.prepareRestore(from: url)
        let asset = try #require(preview.manifest.assets.first)
        let staged = root.appending(path: "archive-staging/\(preview.id)/\(asset.digest)")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: staged.path)
        try Data("tampered".utf8).write(to: staged)
        await #expect(throws: PocketArchiveError.self) { try await store.commitRestore(preview.id, revision: 1) }
        #expect(try await store.loadCollection() == before); #expect(try await store.recoverableCollection() == nil)
        try await store.closeArchive(preview.id)
    }
}
