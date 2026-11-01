import Foundation

/// An editing projection of the existing plain-text scratchpad, not a second
/// storage format. Untouched text and original line endings round-trip exactly.
nonisolated struct ScratchpadDocument {
    struct Line: Identifiable {
        let id = UUID()
        var content: String
        var ending: String

        private var marker: String.Index? {
            var index = content.startIndex
            while index < content.endIndex, content[index] == " " || content[index] == "\t" {
                index = content.index(after: index)
            }
            if content[index...].hasPrefix("- ") || content[index...].hasPrefix("* ") {
                index = content.index(index, offsetBy: 2)
            }
            let suffix = content[index...]
            guard suffix.hasPrefix("[ ]") || suffix.hasPrefix("[x]") || suffix.hasPrefix("[X]") else { return nil }
            return content.index(after: index)
        }

        var isCompleted: Bool? { marker.map { content[$0] != " " } }

        var label: String {
            guard let marker else { return content }
            let start = content.index(marker, offsetBy: 2)
            let suffix = content[start...]
            return String(suffix.first == " " || suffix.first == "\t" ? suffix.dropFirst() : suffix)
        }

        mutating func setCompleted(_ completed: Bool) {
            guard let marker else { return }
            content.replaceSubrange(marker...marker, with: completed ? "x" : " ")
        }
    }

    private(set) var lines: [Line]
    var text: String { lines.map { $0.content + $0.ending }.joined() }
    var taskCount: Int { lines.filter { $0.isCompleted != nil }.count }
    var completedCount: Int { lines.filter { $0.isCompleted == true }.count }

    init(_ source: String) {
        lines = []
        let string = source as NSString
        var position = 0
        while position < string.length {
            var end = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: position, length: 0))
            lines.append(Line(content: string.substring(with: NSRange(location: position, length: contentsEnd - position)),
                              ending: string.substring(with: NSRange(location: contentsEnd, length: end - contentsEnd))))
            position = end
        }
    }

    mutating func setCompleted(_ completed: Bool, id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].setCompleted(completed)
    }

    static let completedLifetime: TimeInterval = 24 * 60 * 60

    /// Ticked tasks leave a day after completion. A ticked task without a recorded
    /// time starts its day now; reopened or reworded tasks lose theirs. Returns
    /// the completion times still in use, keyed by trimmed task label.
    mutating func removeExpiredTasks(completedAt times: [String: Date], now: Date) -> [String: Date] {
        let endsWithoutBreak = lines.last?.ending.isEmpty == true
        var kept: [String: Date] = [:]
        lines.removeAll { line in
            guard line.isCompleted == true else { return false }
            let key = line.label.trimmingCharacters(in: .whitespaces)
            let completed = times[key] ?? now
            if now.timeIntervalSince(completed) >= Self.completedLifetime { return true }
            kept[key] = completed
            return false
        }
        // Removing the unterminated final line must not leave a new trailing break.
        if endsWithoutBreak, let last = lines.indices.last { lines[last].ending = "" }
        return kept
    }

    @discardableResult
    mutating func appendTask(_ title: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        let ending = lines.first(where: { !$0.ending.isEmpty })?.ending ?? "\n"
        if let last = lines.indices.last, lines[last].ending.isEmpty { lines[last].ending = ending }
        // Multiline pastes create individual tasks. Existing note bytes stay intact.
        let additions = ScratchpadDocument(title).lines.filter { !$0.content.trimmingCharacters(in: .whitespaces).isEmpty }
        for (offset, line) in additions.enumerated() {
            lines.append(Line(content: "[ ] " + line.content, ending: offset < additions.count - 1 ? ending : ""))
        }
        return !additions.isEmpty
    }
}
