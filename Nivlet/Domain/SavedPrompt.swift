import Foundation

nonisolated struct SavedPrompt: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var label: String
    var source: String
    var isFavorite = false
    var usesFields = false

    var template: PromptTemplate? {
        usesFields ? try? PromptTemplate.parse(source, label: label) : PromptTemplate(label: label, segments: [.text(source)])
    }
}

nonisolated struct LibrarySnapshot: Identifiable, Equatable, Sendable, Codable {
    var pocketID: UUID
    var pocketName: String
    var prompts: [SavedPrompt]
    var references: [ReferenceItem]
    var note: String

    var view: PocketViewBookmark? = nil
    /// When each ticked scratchpad task was completed, keyed by trimmed label.
    var completedTasks: [String: Date] = [:]
    var id: UUID { pocketID }

    static var empty: LibrarySnapshot { LibrarySnapshot(pocketID: UUID(), pocketName: "My pocket", prompts: [], references: [], note: "") }
}

nonisolated extension LibrarySnapshot {
    enum CodingKeys: String, CodingKey {
        case pocketID, pocketName, prompts, references, note, view, completedTasks
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pocketID = try values.decode(UUID.self, forKey: .pocketID)
        pocketName = try values.decode(String.self, forKey: .pocketName)
        prompts = try values.decode([SavedPrompt].self, forKey: .prompts)
        references = try values.decode([ReferenceItem].self, forKey: .references)
        note = try values.decode(String.self, forKey: .note)
        view = try values.decodeIfPresent(PocketViewBookmark.self, forKey: .view)
        // Recovery journals written before to-do expiry have no completion map.
        // Keep those pending edits readable across an app update.
        completedTasks = try values.decodeIfPresent([String: Date].self, forKey: .completedTasks) ?? [:]
    }
}
