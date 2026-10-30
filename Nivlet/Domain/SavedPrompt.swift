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
    var id: UUID { pocketID }

    static var empty: LibrarySnapshot { LibrarySnapshot(pocketID: UUID(), pocketName: "My pocket", prompts: [], references: [], note: "") }
}
