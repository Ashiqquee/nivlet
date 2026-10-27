import Foundation
import Testing
@testable import Nivlet

@Suite("Scratchpad checklists")
struct ScratchpadDocumentTests {
    @Test("Viewing a note never rewrites its text", arguments: ["", "A note  \n\n", "Notes\r\n[ ] First 👩🏽‍💻\r\n[x] Second\r\n", "A\rB\u{2028}C\u{2029}D\0🙂"])
    func losslessProjection(_ text: String) {
        #expect(ScratchpadDocument(text).text == text)
    }

    @Test("Toggling edits only the selected marker and keeps row identity")
    func toggle() throws {
        let source = "Notes  \r\n\t- [ ] First 👩🏽‍💻  \r\n* [X] Second\r\n[x]No space\r\nNot [ ] a task"
        var document = ScratchpadDocument(source)
        let ids = document.lines.map(\.id)
        let first = try #require(document.lines.first(where: { $0.isCompleted == false }))
        #expect(first.label == "First 👩🏽‍💻  ")
        document.setCompleted(true, id: first.id)
        #expect(document.text == source.replacingOccurrences(of: "[ ] First", with: "[x] First"))
        #expect(document.lines.map(\.id) == ids)
        #expect(document.completedCount == 3)
        document.setCompleted(false, id: first.id)
        #expect(document.text == source)
        #expect(document.taskCount == 3)
    }

    @Test("Malformed brackets and ordinary text never become tasks", arguments: ["[yes] Task", "A [ ] phrase", "[ ]", "[x]", "[", "  "])
    func markerRecognition(_ text: String) {
        let document = ScratchpadDocument(text)
        let expected = text == "[ ]" || text == "[x]" ? 1 : 0
        #expect(document.taskCount == expected)
    }

    @Test("Appending tasks preserves existing text, line endings and row IDs")
    func append() {
        var document = ScratchpadDocument("Notes\r\nKeep whitespace  ")
        let ids = document.lines.map(\.id)
        let added = document.appendTask("  Next step\nAnother step  ")
        #expect(added)
        #expect(document.text == "Notes\r\nKeep whitespace  \r\n[ ] Next step\r\n[ ] Another step")
        #expect(Array(document.lines.prefix(2)).map(\.id) == ids)
        let before = document.text
        let addedEmpty = document.appendTask(" \n\t")
        #expect(!addedEmpty)
        #expect(document.text == before)
    }

    @Test("Task completion and additions survive library relaunch")
    func persistence() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "nivlet-checklist-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let kit = PocketLibrary(root: root)
        await kit.load()
        kit.note = "My note\n[ ] Ship the draft"
        var document = ScratchpadDocument(kit.note)
        let task = try #require(document.lines.first(where: { $0.isCompleted != nil }))
        document.setCompleted(true, id: task.id)
        document.appendTask("Check tomorrow")
        kit.note = document.text
        #expect(await kit.flush())
        let reopened = PocketLibrary(root: root)
        await reopened.load()
        #expect(reopened.note == "My note\n[x] Ship the draft\n[ ] Check tomorrow")
        #expect(ScratchpadDocument(reopened.note).completedCount == 1)
    }
}
