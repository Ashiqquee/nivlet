import Foundation

nonisolated struct TrashedPocket: Identifiable, Equatable, Sendable, Codable {
    var pocket: LibrarySnapshot
    var deletedAt: Date
    var id: UUID { pocket.pocketID }
    var expiresAt: Date { deletedAt.addingTimeInterval(7 * 24 * 60 * 60) }
    func canRestore(at now: Date) -> Bool { now < expiresAt }
}

/// A complete metadata revision. Live, trashed and pending ownership travel together.
nonisolated struct PocketCollection: Equatable, Sendable, Codable {
    var pockets: [LibrarySnapshot]
    var trash: [TrashedPocket] = []
    var activePocketID: UUID

    init(pocket: LibrarySnapshot) { pockets = [pocket]; activePocketID = pocket.pocketID }
    init(pockets: [LibrarySnapshot], trash: [TrashedPocket] = [], activePocketID: UUID) {
        self.pockets = pockets; self.trash = trash; self.activePocketID = activePocketID
    }

    func validate() throws {
        let all = pockets + trash.map(\.pocket)
        guard !pockets.isEmpty, pockets.contains(where: { $0.pocketID == activePocketID }),
              Set(all.map(\.pocketID)).count == all.count,
              all.allSatisfy({ PromptTemplate.isFilled($0.pocketName) }) else { throw LibraryStoreError.database("pocket ownership") }
        let ids = all.flatMap { $0.prompts.map(\.id) + $0.references.map(\.id) }
        guard Set(ids).count == ids.count else { throw LibraryStoreError.database("item ownership") }
    }

    /// Live and retained-trash ownership. Cleanup additionally checks Undo,
    /// pending saves/imports, migration backups and durable archive pins.
    var assetReferenceCounts: [URL: Int] {
        var counts: [URL: Int] = [:]
        for pocket in pockets + trash.map(\.pocket) {
            for reference in pocket.references { counts[reference.originalURL, default: 0] += 1 }
        }
        return counts
    }
}

nonisolated enum PocketSearchScope: String, CaseIterable, Identifiable, Codable {
    case active = "This pocket", all = "All pockets"
    var id: String { rawValue }
}

nonisolated struct PocketSearchResult: Identifiable, Equatable {
    let pocketID: UUID
    let pocketName: String
    let id: UUID
    let tool: PanelTool
    let label: String
    let excerpt: String
}

extension PocketCollection {
    /// Searches reviewed metadata only; never opens original files or includes trash.
    func search(_ query: String, scope: PocketSearchScope) -> [PocketSearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return pockets.filter { scope == .all || $0.pocketID == activePocketID }.flatMap { pocket in
            pocket.prompts.filter { $0.label.localizedStandardContains(term) || $0.source.localizedStandardContains(term) }
                .map { PocketSearchResult(pocketID: pocket.pocketID, pocketName: pocket.pocketName, id: $0.id,
                                          tool: .prompts, label: $0.label, excerpt: $0.source) }
            + pocket.references.filter { $0.label.localizedStandardContains(term) || $0.note.localizedStandardContains(term) }
                .map { PocketSearchResult(pocketID: pocket.pocketID, pocketName: pocket.pocketName, id: $0.id,
                                          tool: .references, label: $0.label, excerpt: $0.note) }
        }
    }
}

/// Device-local navigation metadata. Unsaved editor text and filled values are
/// deliberately separate, in-memory drafts; they never enter saved source.
nonisolated struct PocketViewBookmark: Equatable, Sendable, Codable {
    var tool: PanelTool = .prompts
    var selection: UUID?
    var query = ""
    var scope: PocketSearchScope = .active
}
