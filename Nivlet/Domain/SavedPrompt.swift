import Foundation

nonisolated struct SavedPrompt: Identifiable, Equatable, Sendable {
    var id = UUID()
    var label: String
    var source: String
    var isFavorite = false
    var usesFields = false

    var template: PromptTemplate? {
        usesFields ? try? PromptTemplate.parse(source, label: label) : PromptTemplate(label: label, segments: [.text(source)])
    }
}

nonisolated struct LibrarySnapshot: Equatable, Sendable {
    var pocketID: UUID
    var pocketName: String
    var instructions: [Instruction]
    var prompts: [SavedPrompt]
    var references: [ReferenceItem]
    var note: String

    static let empty = LibrarySnapshot(pocketID: UUID(), pocketName: "My pocket", instructions: [], prompts: [], references: [], note: "")
}
