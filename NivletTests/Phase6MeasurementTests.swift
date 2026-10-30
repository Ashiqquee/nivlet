import AppKit
import Foundation
import ImageIO
import Testing
@testable import Nivlet

// Timing samples share one machine and main actor; run this suite alone for
// the report. Serialization avoids measuring its own fixtures against each other.
@Suite("Phase 6 measurements", .serialized)
struct Phase6MeasurementTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "nivlet-phase6-measure-\(UUID().uuidString)")
    }

    @Test("Reopened 200/1,000-item pockets retain exact content with measured load and search", arguments: [200, 1000])
    func measuredPocket(itemCount: Int) async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        var pocket = try await store.load()
        pocket.prompts = (0..<itemCount).map {
            SavedPrompt(label: "Prompt \($0)", source: "Reviewed text \($0) ✅ with {{literal}} and a newline.\nNext task.", isFavorite: $0 % 10 == 0)
        }
        #expect(try await store.save(pocket, revision: 1))
        var loads: [Double] = []
        for _ in 0..<30 {
            let start = ProcessInfo.processInfo.systemUptime
            let reopened = try await LibraryStore(root: folder).load()
            loads.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            #expect(reopened == pocket)
        }
        let collection = PocketCollection(pocket: pocket)
        var searches: [Double] = []
        for _ in 0..<100 {
            let start = ProcessInfo.processInfo.systemUptime
            let results = collection.search("Reviewed", scope: .active)
            searches.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            #expect(results.count == itemCount)
            #expect(results.last?.excerpt == pocket.prompts.last?.source)
        }
        report("load-\(itemCount)", loads); report("search-\(itemCount)", searches)
    }

    @Test("Exact clipboard completion and feedback measured on a private pasteboard")
    func measuredCopy() {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        let model = PanelModel(pasteboard: board)
        let text = "Reviewed ✅\n\n{{literal}}  "
        var copies: [Double] = []
        for _ in 0..<100 {
            let start = ProcessInfo.processInfo.systemUptime
            model.copy(text)
            copies.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            #expect(board.string(forType: .string) == text)
            #expect(model.feedback == "Copied to clipboard")
        }
        model.dismissFeedback()
        report("copy-feedback", copies)
    }

    @Test("Bounded native thumbnail decoding with a concurrent main-actor heartbeat")
    func measuredThumbnail() async throws {
        let url = try #require(Bundle.main.url(forResource: "landing-layout", withExtension: "png"))
        var decoding: [Double] = []
        var heartbeat: [Double] = []
        let pulse = Task {
            var previous = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(2)) } catch { break }
                let now = ProcessInfo.processInfo.systemUptime
                heartbeat.append((now - previous) * 1000); previous = now
            }
        }
        for _ in 0..<30 {
            let start = ProcessInfo.processInfo.systemUptime
            let content = await ReferencePreviewLoader.load(url, image: true, maxPixels: 600)
            decoding.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            guard case .image(let data) = content else { Issue.record("Expected bounded PNG"); continue }
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect((properties[kCGImagePropertyPixelWidth] as? Int ?? 0) <= 600)
            #expect((properties[kCGImagePropertyPixelHeight] as? Int ?? 0) <= 600)
        }
        pulse.cancel(); await pulse.value
        report("thumbnail-600", decoding)
        if !heartbeat.isEmpty { report("main-actor-heartbeat", heartbeat) }
    }

    private func report(_ name: String, _ samples: [Double]) {
        let ordered = samples.sorted()
        let data: [String: Any] = ["metric": name, "unit": "ms", "n": samples.count,
            "p50": ordered[(ordered.count - 1) / 2], "p95": ordered[Int(ceil(Double(ordered.count) * 0.95)) - 1],
            "max": ordered.last!, "samples": samples]
        if let json = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]), let text = String(data: json, encoding: .utf8) {
            print("PHASE6_METRIC \(text)")
            Attachment.record(text, named: name + ".json")
        }
    }
}
