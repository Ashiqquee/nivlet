import Foundation

struct PocketMoveRequest: Identifiable {
    let id: UUID
    let tool: PanelTool
}

extension PanelModel {
    struct PocketViewState {
        var tool: PanelTool
        var inspector: PanelInspector?
        var draft: TextDraft?
        var query: String
        var scope: PocketSearchScope
        var selection: UUID?
    }

    var bookmark: PocketViewBookmark { PocketViewBookmark(tool: tool, selection: selection, query: query, scope: searchScope) }

    func rememberPocket(_ id: UUID) {
        pocketViews[id] = PocketViewState(tool: tool, inspector: inspector, draft: draft, query: query,
                                         scope: searchScope, selection: selection)
    }

    func restorePocketView(_ kit: PocketLibrary) {
        let state = pocketViews[kit.pocketID]
        let saved = kit.currentView
        tool = state?.tool ?? saved?.tool ?? .prompts
        inspector = state?.inspector; draft = state?.draft
        query = state?.query ?? saved?.query ?? ""; searchScope = state?.scope ?? saved?.scope ?? .active
        selection = state?.selection ?? saved?.selection; actionsOpen = false
        revealRequest = selection
        reconcileSelection(kit)
    }

    @discardableResult
    func switchPocket(to id: UUID, kit: PocketLibrary) async -> Bool {
        guard !kit.isSwitching, !kit.isImporting else { return false }
        rememberPocket(kit.pocketID)
        kit.updateView(bookmark)
        guard await kit.switchPocket(to: id) else { return false }
        restorePocketView(kit)
        return true
    }

    func deletePocket(kit: PocketLibrary) async {
        rememberPocket(kit.pocketID)
        kit.updateView(bookmark)
        if await kit.deletePocket() { restorePocketView(kit) }
    }

    func openSearchResult(_ result: PocketSearchResult, kit: PocketLibrary) async {
        if result.pocketID != kit.pocketID {
            guard await switchPocket(to: result.pocketID, kit: kit) else { return }
        }
        if draft?.hasChanges == true {
            showFeedback("Finish editing or discard this pocket’s draft before opening a search result.", isError: true)
            return
        }
        tool = result.tool; query = ""; selection = result.id; actionsOpen = false
        inspector = result.tool == .prompts ? .prompt(result.id) : .reference(result.id)
        draft = nil
    }

    func finishMove(to destination: UUID, kit: PocketLibrary) {
        guard let request = moveRequest else { return }
        if kit.moveItem(id: request.id, tool: request.tool, to: destination) {
            // A moved source keeps its identity; its filled values are deliberately
            // reset so a destination never inherits a draft from another kit.
            fieldValues[request.id] = nil
            preparedReferenceURLs[request.id] = nil
            reconcileSelection(kit)
        }
        moveRequest = nil
    }

    func reconcileSelection(_ kit: PocketLibrary) {
        if let selection, !ShelfIndex.orderedIDs(tool, kit: kit, query: query).contains(selection) { self.selection = nil; actionsOpen = false }
        switch inspector {
        case .prompt(let id) where !kit.prompts.contains(where: { $0.id == id }): inspector = nil
        case .reference(let id) where !kit.references.contains(where: { $0.id == id }): inspector = nil
        case .editor:
            if let id = draft?.id, !kit.prompts.contains(where: { $0.id == id }) { draft = nil; inspector = nil }
        default: break
        }
    }

    func handleSearch(_ key: ShelfKey, kit: PocketLibrary) -> Bool {
        let results = kit.search(query, scope: searchScope)
        guard !results.isEmpty else { return key == .up || key == .down || key == .enter }
        let index = results.firstIndex { $0.id == selection } ?? 0
        switch key {
        case .up: selection = results[max(0, index - 1)].id; revealRequest = selection
        case .down: selection = results[min(results.count - 1, index + 1)].id; revealRequest = selection
        case .enter, .open:
            let result = results[index]
            Task { await openSearchResult(result, kit: kit) }
        default: return false
        }
        return true
    }
}
