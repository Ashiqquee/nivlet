import AppKit
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Nivlet

@Suite("Phase 3 one-pocket slice")
struct Phase3VerticalSliceTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appending(path: "nivlet-phase3-\(UUID().uuidString)") }
    private func file(_ root: URL, _ name: String, bytes: Data = Data("Original ✅\r\n".utf8)) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: name)
        try bytes.write(to: url)
        return url
    }

    @Test("Previously open grammar cases are explicit", arguments: [
        (#"\{"#, "{"), (#"\}"#, "}"), (#"\{\{literal\}\}"#, "{{literal}}"),
        (#"C:\files\name"#, #"C:\files\name"#), (#"tail\"#, #"tail\"#),
        (#"\\{"#, #"\{"#), (#"\\\}"#, #"\\}"#), ("Unicode 日本語 👩🏽‍💻", "Unicode 日本語 👩🏽‍💻")
    ])
    func grammarLiterals(source: String, expected: String) throws {
        #expect(try PromptTemplate.parse(source).render([:]) == expected)
    }

    @Test("Invalid token names, spacing and lone braces are rejected", arguments: [
        "{", "}", "{{ name }}", "{{name }}", "{{ name}}", "{{é}}", "{{名字}}", "{{_name}}", "{{a.b}}", "{{a\nb}}", "{{{name}}}", "{{name}"
    ])
    func malformed(source: String) { #expect(throws: PromptTemplate.ParseError.self) { try PromptTemplate.parse(source) } }

    @Test("Rendered preview and copied text match exactly; values are not reparsed", arguments: [
        "{{other}}", "Line one\r\n\nLine two\r", "  e\u{301} 👩🏽‍💻 日本語  ", #"\{\{x\}\}"#
    ])
    @MainActor
    func previewCopy(value: String) throws {
        let template = try PromptTemplate.parse(#"\{\{literal\}\}: {{topic}} / {{Topic}} / {{topic}}"#)
        #expect(template.fieldNames == ["topic", "Topic"])
        let values = ["topic": value, "Topic": "case-sensitive"]
        let rendered = try #require(template.render(values))
        #expect(template.preview(values).map(\.text).joined() == rendered)
        let board = NSPasteboard(name: .init("nivlet-phase3-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        #expect(TextCopier.copy(rendered, to: board))
        #expect(Array((try #require(board.string(forType: .string))).utf8) == Array(rendered.utf8))
    }

    @Test("Twenty mixed originals survive source removal, restart and independent exports")
    @MainActor
    func twentyOriginals() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let libraryRoot = folder.appending(path: "library")
        let library = PocketLibrary(root: libraryRoot)
        await library.load()
        let png = try Data(contentsOf: #require(Bundle(for: ShellController.self).url(forResource: "landing-layout", withExtension: "png")))
        let pdfURL = folder.appending(path: "fixture.pdf")
        var page = CGRect(x: 0, y: 0, width: 600, height: 800)
        let pdf = try #require(CGContext(pdfURL as CFURL, mediaBox: &page, nil))
        pdf.beginPDFPage(nil); pdf.endPDFPage(); pdf.closePDF()
        let pdfBytes = try Data(contentsOf: pdfURL)
        let extensions = ["png", "txt", "md", "json", "bin", "html", "swift", "csv", "pdf", "dat"]
        var sources: [URL] = [], expected: [Data] = []
        for index in 0..<20 {
            let name = index < 2 ? "same.txt" : "Reference \(index) ✅.\(extensions[index % 10])"
            let bytes: Data
            switch index % 10 {
            case 0: bytes = png
            case 3: bytes = try JSONSerialization.data(withJSONObject: ["fixture": index])
            case 4, 9: bytes = Data((0..<256).map { UInt8(truncatingIfNeeded: $0 + index) })
            case 5: bytes = Data("<html><script>NEVER execute</script></html>".utf8)
            case 7: bytes = Data("row,value\nfixture,\(index)\n".utf8)
            case 8: bytes = pdfBytes
            default: bytes = Data("Fixture \(index)\r\n".utf8)
            }
            sources.append(try file(folder.appending(path: "sources/\(index)"), name, bytes: bytes)); expected.append(bytes)
        }
        #expect(await library.importFiles(sources).isEmpty)
        #expect(library.importResults.count == 20)
        #expect(library.importResults.allSatisfy { $0.state == .saved })
        let names = sources.map(\.lastPathComponent)
        try FileManager.default.removeItem(at: folder.appending(path: "sources"))
        let reopened = PocketLibrary(root: libraryRoot)
        await reopened.load()
        #expect(reopened.references.count == 20)
        #expect(reopened.references.map(\.displayName) == names)
        let handoff = FileHandoff(exportRoot: folder.appending(path: "exports"))
        for (index, reference) in reopened.references.enumerated() {
            #expect(try Data(contentsOf: reference.originalURL) == expected[index])
            let exported = try handoff.exportCopy(of: reference.originalURL, displayName: reference.displayName)
            #expect(try FileHandoff.sha256(of: exported) == FileHandoff.sha256(of: reference.originalURL))
            #expect(exported.lastPathComponent == names[index])
            #expect(exported != reference.originalURL)
        }
        #expect(reopened.references[0].originalURL == reopened.references[10].originalURL)
        #expect(reopened.references[0].displayName != reopened.references[10].displayName)
        #expect(reopened.references[0].originalURL != reopened.references[1].originalURL)
    }

    @Test("Partial import retries only failures and does not duplicate successful items")
    @MainActor
    func partialRetry() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let good = try file(folder.appending(path: "sources"), "good.txt")
        let missing = good.deletingLastPathComponent().appending(path: "missing.txt")
        let library = PocketLibrary(root: folder.appending(path: "library"))
        await library.load()
        #expect(await library.importFiles([good, missing]).count == 1)
        #expect(library.references.count == 1)
        let originalID = library.references[0].id
        #expect(library.failedImportIDs.count == 1)
        try Data("Recovered source".utf8).write(to: missing)
        #expect(await library.retryImports(library.failedImportIDs).isEmpty)
        #expect(library.references.count == 2)
        #expect(library.references[0].id == originalID)
        #expect(library.importResults.allSatisfy { $0.state == .saved })
    }

    @Test("Metadata failure stays visibly unsaved and retry uses staged bytes without a source")
    @MainActor
    func metadataFailure() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "source.txt")
        let store = LibraryStore(root: folder.appending(path: "library"))
        let library = PocketLibrary(store: store)
        await library.load()
        await store.failNextCommitForTesting()
        #expect(await library.importFiles([source]).count == 1)
        let id = try #require(library.references.first?.id)
        #expect(library.referenceIsPending(id))
        #expect(try await store.load().references.isEmpty)
        try FileManager.default.removeItem(at: source)
        #expect(await library.retryImports(library.failedImportIDs).isEmpty)
        #expect(library.references.map(\.id) == [id])
        #expect(!library.referenceIsPending(id))
        #expect(try await store.load().references.map(\.id) == [id])
    }

    @Test("Staging/placement failures never publish metadata and retries adopt original bytes",
          arguments: [ReferenceAssetStore.FailurePoint.afterStaging, .afterPlacement])
    func assetFailure(point: ReferenceAssetStore.FailurePoint) async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "original.txt")
        let libraryRoot = folder.appending(path: "library")
        let assets = ReferenceAssetStore(root: libraryRoot)
        let store = LibraryStore(root: libraryRoot, assets: assets)
        _ = try await store.load()
        await assets.failNextImportForTesting(at: point)
        await #expect(throws: LibraryStoreError.self) { try await store.importFile(source) }
        #expect(try await store.load().references.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: libraryRoot.appending(path: "staging").path).isEmpty)
        let imported = try await store.importFile(source)
        #expect(try Data(contentsOf: imported.originalURL) == Data(contentsOf: source))
    }

    @Test("Directories, symlinks, named pipes and network URLs are rejected without traversal")
    func rejectNonFiles() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "source.txt")
        let link = folder.appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let fifo = folder.appending(path: "pipe")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        let store = LibraryStore(root: folder.appending(path: "library"))
        for candidate in [folder, link, fifo, URL(string: "https://example.com/file.png")!] {
            await #expect(throws: LibraryStoreError.self) { try await store.importFile(candidate) }
        }
    }

    @Test("Size boundaries warn, require confirmation above 500 MB, and reject above 2 GB")
    func sizePolicy() throws {
        let limits = ReferenceImportLimits()
        #expect(!limits.warns(100_000_000))
        #expect(limits.warns(100_000_001))
        try limits.validate(500_000_000, confirmed: false)
        #expect(throws: LibraryStoreError.self) { try limits.validate(500_000_001, confirmed: false) }
        try limits.validate(2_000_000_000, confirmed: true)
        #expect(throws: LibraryStoreError.self) { try limits.validate(2_000_000_001, confirmed: true) }
    }

    @Test("Large-file confirmation retries the selected item only, using scaled byte limits")
    @MainActor
    func confirmLarge() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "large.bin", bytes: Data(repeating: 7, count: 20))
        let libraryRoot = folder.appending(path: "library")
        let assets = ReferenceAssetStore(root: libraryRoot, limits: .init(warningBytes: 8, confirmationBytes: 16, maximumBytes: 32))
        let library = PocketLibrary(store: LibraryStore(root: libraryRoot, assets: assets))
        await library.load()
        #expect(await library.importFiles([source]).isEmpty)
        #expect(library.references.isEmpty)
        let result = try #require(library.importResults.first)
        #expect(result.state == .needsConfirmation)
        #expect(await library.retryImports([result.id], confirmed: true).isEmpty)
        #expect(library.references.count == 1)
        #expect(library.importResults[0].state == .saved)
    }

    @Test("Reference label and note edits preserve filename and original bytes across restart")
    @MainActor
    func referenceMetadata() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "original.txt")
        let libraryRoot = folder.appending(path: "library")
        let library = PocketLibrary(root: libraryRoot)
        await library.load(); _ = await library.importFiles([source])
        let item = try #require(library.references.first)
        library.renameReference(id: item.id, label: "New label ✅")
        library.updateReference(id: item.id, note: "A separate note\r\n")
        #expect(await library.flush())
        let loaded = try #require(try await LibraryStore(root: libraryRoot).load().references.first)
        #expect(loaded.label == "New label ✅")
        #expect(loaded.note == "A separate note\r\n")
        #expect(loaded.displayName == "original.txt")
        #expect(!loaded.isImage)
        #expect(try FileHandoff.sha256(of: loaded.originalURL) == FileHandoff.sha256(of: source))
    }

    @Test("Bounded previews are static; long UTF-8 text reports truncation, binary falls back")
    func previews() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let long = try file(folder, "long.txt", bytes: Data((String(repeating: "a", count: 32 * 1024 - 1) + "🙂tail").utf8))
        guard case .text(let text, let truncated) = await ReferencePreviewLoader.load(long, image: false) else { Issue.record("Expected bounded text"); return }
        #expect(truncated); #expect(text.utf8.count <= 32 * 1024); #expect(!text.contains("�"))
        let html = try file(folder, "active.html", bytes: Data("<script>fetch('https://example.com')</script>".utf8))
        guard case .text(let literal, _) = await ReferencePreviewLoader.load(html, image: false) else { Issue.record("Expected literal HTML text"); return }
        #expect(literal.contains("<script>"))
        let binary = try file(folder, "binary.bin", bytes: Data([0, 255, 7]))
        guard case .unavailable = await ReferencePreviewLoader.load(binary, image: false) else { Issue.record("Expected binary fallback"); return }
        let png = try #require(Bundle(for: ShellController.self).url(forResource: "landing-layout", withExtension: "png"))
        guard case .image(let bytes) = await ReferencePreviewLoader.load(png, image: true, maxPixels: 96),
              let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { Issue.record("Expected bounded thumbnail"); return }
        #expect((properties[kCGImagePropertyPixelWidth] as? Int ?? 0) <= 96)
        #expect((properties[kCGImagePropertyPixelHeight] as? Int ?? 0) <= 96)
    }

    @Test("Paste consumes files before rendered images and never treats remote URLs/text as files")
    @MainActor
    func explicitPaste() throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try file(folder, "first.txt"), second = try file(folder, "second.txt")
        let board = NSPasteboard(name: .init("nivlet-phase3-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.writeObjects([first as NSURL, second as NSURL])
        #expect(ReferencePasteboard.canPaste(from: board))
        #expect(ReferencePasteboard.readForExplicitPaste(from: board).count == 2)
        board.clearContents(); board.setString("https://example.com/remote.png", forType: .string)
        #expect(!ReferencePasteboard.canPaste(from: board))
        #expect(ReferencePasteboard.readForExplicitPaste(from: board).isEmpty)
        board.clearContents(); board.setData(Data([7, 8, 9]), forType: .png)
        guard case .image(let bytes, let name) = ReferencePasteboard.readForExplicitPaste(from: board).first else { Issue.record("Expected explicit image bytes"); return }
        #expect(bytes == Data([7, 8, 9])); #expect(name == "Pasted image.png")
    }

    @Test("Modified exports cannot mutate assets or poison a future transfer")
    func independentExports() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "source.txt")
        let item = try await LibraryStore(root: folder.appending(path: "library")).importFile(source)
        let handoff = FileHandoff(exportRoot: folder.appending(path: "exports"))
        let first = try handoff.exportCopy(of: item.originalURL, displayName: item.displayName)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: first.path)
        try Data("Changed by destination".utf8).write(to: first)
        let second = try handoff.exportCopy(of: item.originalURL, displayName: item.displayName)
        #expect(first != second)
        #expect(try Data(contentsOf: second) == Data(contentsOf: source))
        #expect(try Data(contentsOf: item.originalURL) == Data(contentsOf: source))
    }
    @Test("Pasted image bytes are owned unchanged and survive relaunch")
    @MainActor
    func pastedImageIntegrity() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let png = try Data(contentsOf: #require(Bundle(for: ShellController.self).url(forResource: "landing-layout", withExtension: "png")))
        let library = PocketLibrary(root: folder)
        await library.load()
        #expect(await library.importSources([.image(png, name: "Pasted image.png")]).isEmpty)
        let loaded = try #require(try await LibraryStore(root: folder).load().references.first)
        #expect(loaded.displayName == "Pasted image.png")
        #expect(loaded.isImage)
        #expect(try Data(contentsOf: loaded.originalURL) == png)
    }

    @Test("PDF preview renders a bounded first page without executing content")
    func pdfPreview() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "layout.pdf")
        var bounds = CGRect(x: 0, y: 0, width: 600, height: 900)
        let context = try #require(CGContext(url as CFURL, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 10, y: 10, width: 80, height: 80))
        context.endPDFPage(); context.closePDF()
        guard case .image(let data) = await ReferencePreviewLoader.load(url, image: false, maxPixels: 120, displayName: "layout.pdf"),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { Issue.record("Expected PDF page thumbnail"); return }
        #expect((properties[kCGImagePropertyPixelHeight] as? Int ?? 0) == 120)
        #expect((properties[kCGImagePropertyPixelWidth] as? Int ?? 0) <= 120)
    }

    @Test("Cancellation cleans staging and cannot publish a reference")
    func cancelledImport() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "source.bin", bytes: Data(repeating: 9, count: 1 << 20))
        let assets = ReferenceAssetStore(root: folder.appending(path: "library"))
        let task = Task { try await assets.importSource(.file(source)) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        let staging = folder.appending(path: "library/staging")
        #expect(try FileManager.default.contentsOfDirectory(atPath: staging.path).isEmpty)
    }

    @Test("Digest validation refuses a corrupted internal asset")
    func corruptedAsset() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "source.txt")
        let store = LibraryStore(root: folder.appending(path: "library"))
        let item = try await store.importFile(source)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: item.originalURL.path)
        try Data("Corrupted bytes".utf8).write(to: item.originalURL)
        #expect(throws: LibraryStoreError.self) {
            try FileHandoff(exportRoot: folder.appending(path: "exports")).exportCopy(of: item.originalURL, displayName: item.displayName)
        }
        await #expect(throws: LibraryStoreError.self) { try await store.importFile(source) }
    }

    @Test("Choosing a replacement retries the failed result without duplicating successes")
    @MainActor
    func reselectFailedSource() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try file(folder, "good.txt")
        let library = PocketLibrary(root: folder.appending(path: "library"))
        await library.load()
        _ = await library.importFiles([source, folder.appending(path: "missing.txt")])
        let failed = try #require(library.failedImportIDs.first)
        let successID = library.references[0].id
        let replacement = try file(folder, "replacement.txt", bytes: Data("Replacement bytes".utf8))
        await library.replaceImportSource(id: failed, with: replacement)
        #expect(library.references.count == 2)
        #expect(library.references[0].id == successID)
        #expect(library.importResults.count == 2)
        #expect(library.importResults[1].state == .saved)
        #expect(library.importResults[1].name == "replacement.txt")
    }

    @Test("Copy file offers unchanged original image bytes and an independent file URL")
    @MainActor
    func copyFileClipboardIntegrity() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let png = try Data(contentsOf: #require(Bundle(for: ShellController.self).url(forResource: "landing-layout", withExtension: "png")))
        let source = try file(folder, "original.png", bytes: png)
        let item = try await LibraryStore(root: folder.appending(path: "library")).importFile(source)
        let board = NSPasteboard(name: .init("nivlet-phase3-copy-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let model = PanelModel(pasteboard: board)
        ReferenceActions.copyFile(item, model: model)
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while model.feedback == "Preparing a file copy…", ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.feedback == "File copied")
        #expect(board.data(forType: .png) == png)
        let urlString = try #require(board.string(forType: .fileURL))
        let copiedURL = try #require(URL(string: urlString))
        defer { try? FileManager.default.removeItem(at: copiedURL.deletingLastPathComponent()) }
        #expect(copiedURL != item.originalURL)
        #expect(try Data(contentsOf: copiedURL) == png)
    }

    @Test("Declared file URLs remain pasteable when source metadata is unavailable")
    @MainActor
    func missingPasteMetadata() async throws {
        let board = NSPasteboard(name: .init("nivlet-phase3-missing-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let missing = URL(fileURLWithPath: "/tmp/nivlet-absent-\(UUID().uuidString)/missing.txt")
        board.writeObjects([missing as NSURL])
        for _ in 0..<5 {
            #expect(ReferencePasteboard.canPaste(from: board))
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(ReferencePasteboard.readForExplicitPaste(from: board).count == 1)
    }

    @Test("An unreadable declared file paste produces an actionable failure instead of disappearing")
    @MainActor
    func invalidDeclaredFilePaste() async throws {
        let folder = root()
        defer { try? FileManager.default.removeItem(at: folder) }
        let board = NSPasteboard(name: .init("nivlet-phase3-invalid-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.setString("not a file URL", forType: .fileURL)
        let sources = ReferencePasteboard.readForExplicitPaste(from: board)
        #expect(sources.count == 1)
        let library = PocketLibrary(root: folder)
        await library.load()
        #expect(await library.importSources(sources).count == 1)
        #expect(library.references.isEmpty)
        #expect(library.failedImportIDs.count == 1)
    }

}
