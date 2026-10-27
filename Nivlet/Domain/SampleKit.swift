import Foundation
import Observation

nonisolated struct Instruction: Identifiable, Equatable, Sendable {
    let id: UUID
    var label: String
    var body: String
    var isFavorite: Bool
}

nonisolated struct ReferenceItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var label: String
    var note: String
    /// Name the receiving app sees when the file is dragged out.
    var displayName: String
    /// Original bytes owned by the app. Phase 1 uses bundled samples.
    var originalURL: URL
    var isImage: Bool
}

/// In-memory sample pocket for the Phase 1 shell. Edits survive tucking and
/// reopening but not quitting; durable storage arrives in Phase 2.
@Observable
final class SampleKit {
    var pocketName = "Website"
    var instructions: [Instruction]
    var prompt: PromptTemplate
    /// Draft values for the prompt, kept separate from the template.
    var promptValues: [String: String] = [:]
    var references: [ReferenceItem]
    var note: String

    init(bundle: Bundle = .main) {
        instructions = [
            Instruction(
                id: UUID(),
                label: "Writing style",
                body: """
                Write in plain, specific language. Short sentences. No hype words like \
                "revolutionary" or "seamless". Prefer concrete examples over adjectives.
                """,
                isFavorite: true
            ),
            Instruction(
                id: UUID(),
                label: "Project constraints",
                body: """
                Static site, no JavaScript framework.
                Must load fast on mobile.
                Keep the existing colour palette and the pricing link in the header.
                """,
                isFavorite: false
            ),
            Instruction(
                id: UUID(),
                label: "Review checklist",
                body: """
                Before you answer:
                • Check the headline is under 10 words.
                • Point out anything that hurts accessibility.
                • List open questions separately — don't guess. ✅
                """,
                isFavorite: false
            ),
        ]
        prompt = PromptTemplate(
            label: "Page critique",
            segments: [
                .text("Review the "),
                .field("page_name"),
                .text(" page for "),
                .field("audience"),
                .text(".\nFocus on: "),
                .field("focus"),
                .text(".\nGive three concrete changes, ordered by impact, and keep the "),
                .field("page_name"),
                .text(" page's current structure unless it blocks the goal."),
            ]
        )
        references = [
            bundle.url(forResource: "landing-layout", withExtension: "png").map {
                ReferenceItem(
                    id: UUID(),
                    label: "Landing layout",
                    note: "Current wireframe. Hero left, image right, three cards below.",
                    displayName: "landing-layout.png",
                    originalURL: $0,
                    isImage: true
                )
            },
            bundle.url(forResource: "page-brief", withExtension: "txt").map {
                ReferenceItem(
                    id: UUID(),
                    label: "Page brief",
                    note: "Audience, goal and tone agreed with the client.",
                    displayName: "page-brief.txt",
                    originalURL: $0,
                    isImage: false
                )
            },
        ].compactMap { $0 }
        note = """
        Next questions
        [ ] Check mobile layout next
        [ ] Ask whether the hero needs a caption
        [x] Share brief with the client
        """
    }
}
