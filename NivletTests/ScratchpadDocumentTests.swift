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

    @Test("Ticked tasks start a day-long timer and leave once it ends")
    func expiry() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let source = "Notes\r\n[x] Old  \r\n[ ] Open\r\n- [X] Recent"
        var document = ScratchpadDocument(source)
        let times = document.removeExpiredTasks(completedAt: ["Recent": start.addingTimeInterval(-60)], now: start)
        // Untimed ticks start now; nothing has expired yet.
        #expect(document.text == source)
        #expect(times == ["Old": start, "Recent": start.addingTimeInterval(-60)])

        let later = start.addingTimeInterval(ScratchpadDocument.completedLifetime - 30)
        let remaining = document.removeExpiredTasks(completedAt: times, now: later)
        // The unterminated final line goes without leaving a trailing break.
        #expect(document.text == "Notes\r\n[x] Old  \r\n[ ] Open")
        #expect(remaining == ["Old": start])

        let final = document.removeExpiredTasks(completedAt: remaining, now: start.addingTimeInterval(ScratchpadDocument.completedLifetime))
        #expect(document.text == "Notes\r\n[ ] Open")
        #expect(final.isEmpty)
    }

    @Test("Reopening a task forgets its completion time")
    func reopenResetsTimer() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var document = ScratchpadDocument("[x] Task")
        var times = document.removeExpiredTasks(completedAt: [:], now: start)
        let task = try #require(document.lines.first)
        document.setCompleted(false, id: task.id)
        times = document.removeExpiredTasks(completedAt: times, now: start.addingTimeInterval(3600))
        #expect(times.isEmpty)
        document.setCompleted(true, id: task.id)
        let ticked = start.addingTimeInterval(7200)
        times = document.removeExpiredTasks(completedAt: times, now: ticked)
        #expect(times == ["Task": ticked])
        _ = document.removeExpiredTasks(completedAt: times, now: start.addingTimeInterval(ScratchpadDocument.completedLifetime + 60))
        #expect(document.text == "[x] Task")
    }

    @Test("Completion times persist and expired tasks leave every live pocket")
    func expiryPersistence() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "nivlet-expiry-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let kit = PocketLibrary(root: root)
        await kit.load()
        kit.note = "[x] Done here\n[ ] Keep"
        let other = try #require(kit.createPocket("Other"))
        #expect(await kit.switchPocket(to: other))
        kit.note = "[x] Done there"
        kit.expireCompletedTasks(now: start)
        #expect(await kit.flush())

        let reopened = PocketLibrary(root: root)
        await reopened.load()
        #expect(reopened.pockets.map(\.completedTasks) == [["Done here": start], ["Done there": start]])
        reopened.expireCompletedTasks(now: start.addingTimeInterval(ScratchpadDocument.completedLifetime))
        #expect(await reopened.flush())
        #expect(reopened.pockets.map(\.note) == ["[ ] Keep", ""])
        #expect(reopened.pockets.allSatisfy { $0.completedTasks.isEmpty })
    }
}
