import Foundation
import Testing
@testable import Nivlet

@Suite("Original-file handoff")
struct FileHandoffTests {
    private let root = FileManager.default.temporaryDirectory
        .appending(path: "nivlet-handoff-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func makeSource(_ bytes: [UInt8], name: String = "source.bin") throws -> URL {
        let folder = root.appending(path: "sources", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data(bytes).write(to: url)
        return url
    }

    @Test("Bundled sample files match their recorded digests")
    func bundledSamplesIntact() throws {
        let bundle = Bundle(for: ShellController.self)
        let png = try #require(bundle.url(forResource: "landing-layout", withExtension: "png"))
        let txt = try #require(bundle.url(forResource: "page-brief", withExtension: "txt"))
        #expect(try FileHandoff.sha256(of: png) == "5dcbca88cc8220c851ae4508d5e98ca2e917a4338d2f7e03d4a773173fc0821c")
        #expect(try FileHandoff.sha256(of: txt) == "633f08a1321a4e18f5403b1282ee687a5c3c5440ceefb487d2add1651bec2ab1")
    }

    @Test("Export copy keeps original bytes and display name, and leaves the source untouched")
    func exportKeepsBytes() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = (0..<300_000).map { UInt8(truncatingIfNeeded: $0 &* 31) }
        let source = try makeSource(bytes)
        let before = try FileHandoff.sha256(of: source)
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: source.path(percentEncoded: false))

        let handoff = FileHandoff(exportRoot: root.appending(path: "exports", directoryHint: .isDirectory))
        let exported = try handoff.exportCopy(of: source, displayName: "Landing layout ✅.png")

        #expect(exported.lastPathComponent == "Landing layout ✅.png")
        #expect(try FileHandoff.sha256(of: exported) == before)
        #expect(try FileHandoff.sha256(of: source) == before)
        let after = try FileManager.default.attributesOfItem(atPath: source.path(percentEncoded: false))
        #expect(after[.modificationDate] as? Date == sourceAttributes[.modificationDate] as? Date)
        #expect(!FileManager.default.isWritableFile(atPath: exported.path(percentEncoded: false)))
    }

    @Test("Each export gets its own folder, so repeated drags never collide")
    func exportsDoNotCollide() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeSource([1, 2, 3])
        let handoff = FileHandoff(exportRoot: root.appending(path: "exports", directoryHint: .isDirectory))
        let first = try handoff.exportCopy(of: source, displayName: "a.bin")
        let second = try handoff.exportCopy(of: source, displayName: "a.bin")
        #expect(first != second)
    }

    @Test("Display names cannot escape the export folder", arguments: ["../../evil.sh", "a/b:c.txt", "..", "   "])
    func safeNames(name: String) {
        let safe = FileHandoff.safeFileName(name)
        #expect(!safe.contains("/"))
        #expect(safe != ".." && safe != "." && !safe.isEmpty)
    }

    @Test("Old exports are removed and recent ones kept")
    func cleanup() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeSource([9])
        let handoff = FileHandoff(exportRoot: root.appending(path: "exports", directoryHint: .isDirectory))
        let exported = try handoff.exportCopy(of: source, displayName: "keep.bin")

        handoff.removeExports(olderThan: 3600)
        #expect(FileManager.default.fileExists(atPath: exported.path(percentEncoded: false)))

        handoff.removeExports(olderThan: 3600, now: .now.addingTimeInterval(7200))
        #expect(!FileManager.default.fileExists(atPath: exported.path(percentEncoded: false)))
    }
}
