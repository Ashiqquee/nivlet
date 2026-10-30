import AppKit
import SwiftUI

/// One row on the instruction/prompt shelf, in display order.
struct TextShelfItem: Identifiable {
    let id: UUID
    let title: String
    let source: String
    let favorite: Bool
    let tool: PanelTool
    var promptTemplate: PromptTemplate? = nil
    var fieldCount: Int { promptTemplate?.fieldNames.count ?? 0 }
    var symbol: String {
        fieldCount > 0 ? "curlybraces" : "text.bubble.fill"
    }
}

/// Keys the shelf list handles while its panel is key. Routed from `ContentPanel`.
enum ShelfKey {
    case up, down, enter, actions, open, edit, duplicate, favorite, delete
}

/// An action for the selected item, shown in the footer and the ⌘K actions panel.
/// `keys` is displayed only for shortcuts that `PanelModel.handle` actually performs.
struct ShelfCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var keys: [String] = []
    var destructive = false
    var enabled = true
    let perform: () -> Void

    /// Short visible labels for the narrow footer, with the full command title
    /// retained for accessibility and the action menu.
    var compactTitle: String {
        switch id {
        case "copy": "Copy"
        case "fill": "Fill in"
        case "open": "Preview"
        default: title
        }
    }
}

/// Single source of truth for what the shelf shows and in which order, so mouse,
/// keyboard and the footer all agree on the selected item.
enum ShelfIndex {
    static func textItems(_ tool: PanelTool, kit: PocketLibrary) -> [TextShelfItem] {
        switch tool {
        case .prompts:
            kit.prompts.map { TextShelfItem(id: $0.id, title: $0.label, source: $0.source, favorite: $0.isFavorite, tool: .prompts, promptTemplate: $0.template) }
        default: []
        }
    }

    static func filtered(_ items: [TextShelfItem], query: String) -> [TextShelfItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedStandardContains(query) || $0.source.localizedStandardContains(query) }
    }

    static func references(kit: PocketLibrary, query: String) -> [ReferenceItem] {
        let filtered = query.isEmpty ? kit.references : kit.references.filter { $0.label.localizedStandardContains(query) || $0.note.localizedStandardContains(query) }
        return filtered.filter(\.isFavorite) + filtered.filter { !$0.isFavorite }
    }

    /// IDs in visual order: favourites first, then the rest.
    static func orderedIDs(_ tool: PanelTool, kit: PocketLibrary, query: String) -> [UUID] {
        switch tool {
        case .prompts:
            let items = filtered(textItems(tool, kit: kit), query: query)
            return items.filter(\.favorite).map(\.id) + items.filter { !$0.favorite }.map(\.id)
        case .references: return references(kit: kit, query: query).map(\.id)
        case .notes: return []
        }
    }
}

extension PanelModel {
    /// The highlighted item, falling back to the first visible one like a launcher list.
    func resolvedSelection(_ kit: PocketLibrary) -> UUID? {
        let ids = ShelfIndex.orderedIDs(tool, kit: kit, query: query)
        if let selection, ids.contains(selection) { return selection }
        return ids.first
    }

    func commands(for id: UUID, kit: PocketLibrary) -> [ShelfCommand] {
        switch tool {
        case .prompts:
            guard let item = ShelfIndex.textItems(tool, kit: kit).first(where: { $0.id == id }) else { return [] }
            return commands(for: item, kit: kit)
        case .references:
            guard let reference = kit.references.first(where: { $0.id == id }) else { return [] }
            return [
                ShelfCommand(id: "open", title: "Open preview", symbol: "eye", keys: ["↵"]) { [weak self] in self?.inspector = .reference(reference.id) },
                ShelfCommand(id: "copy-file", title: "Copy file", symbol: "doc.on.clipboard") { [weak self] in
                    guard let self else { return }
                    ReferenceActions.copyFile(reference, model: self)
                },
                ShelfCommand(id: "copy-note", title: "Copy note", symbol: "doc.on.doc", enabled: !reference.note.isEmpty) { [weak self] in
                    self?.copy(reference.note, from: reference.id)
                },
                ShelfCommand(id: "reveal", title: "Reveal in Finder", symbol: "folder") { [weak self] in
                    guard let self else { return }
                    ReferenceActions.reveal(reference, model: self)
                },
                ShelfCommand(id: "favorite", title: reference.isFavorite ? "Remove favourite" : "Add favourite", symbol: "star", keys: ["⇧", "⌘", "F"]) { kit.toggleFavorite(id: reference.id, tool: .references) },
                ShelfCommand(id: "duplicate", title: "Duplicate", symbol: "plus.square.on.square", keys: ["⌘", "D"]) { kit.duplicate(id: reference.id, tool: .references) },
                ShelfCommand(id: "move-up", title: "Move up", symbol: "arrow.up", enabled: kit.canMoveReference(id: reference.id, by: -1)) { kit.moveReference(id: reference.id, by: -1) },
                ShelfCommand(id: "move-down", title: "Move down", symbol: "arrow.down", enabled: kit.canMoveReference(id: reference.id, by: 1)) { kit.moveReference(id: reference.id, by: 1) },
                ShelfCommand(id: "move-pocket", title: "Move to pocket…", symbol: "folder", enabled: kit.pockets.count > 1 && !kit.isImporting) { [weak self] in self?.moveRequest = PocketMoveRequest(id: reference.id, tool: .references) },
                ShelfCommand(id: "delete", title: "Delete", symbol: "trash", keys: ["⌘", "⌫"], destructive: true) { kit.delete(id: reference.id, tool: .references) },
            ]
        case .notes: return []
        }
    }

    /// Rows already hold their item; this avoids rebuilding and re-parsing the whole shelf per row.
    func commands(for item: TextShelfItem, kit: PocketLibrary) -> [ShelfCommand] {
        let primary: ShelfCommand = item.fieldCount > 0
            ? ShelfCommand(id: "fill", title: "Fill in blanks", symbol: "curlybraces", keys: ["↵"]) { [weak self] in self?.open(item) }
            : ShelfCommand(id: "copy", title: "Copy \(item.tool.itemName)", symbol: "doc.on.doc", keys: ["↵"]) { [weak self] in
                self?.copy(item.promptTemplate?.render([:]) ?? item.source, from: item.id)
            }
        return [
            primary,
            ShelfCommand(id: "open", title: "Open preview", symbol: "eye", keys: ["⌘", "O"]) { [weak self] in self?.open(item) },
            ShelfCommand(id: "edit", title: "Edit…", symbol: "pencil", keys: ["⌘", "E"]) { [weak self] in self?.edit(item, kit: kit) },
            ShelfCommand(id: "favorite", title: item.favorite ? "Remove favourite" : "Add favourite",
                         symbol: item.favorite ? "star.slash" : "star", keys: ["⇧", "⌘", "F"]) { kit.toggleFavorite(id: item.id, tool: item.tool) },
            ShelfCommand(id: "duplicate", title: "Duplicate", symbol: "plus.square.on.square", keys: ["⌘", "D"]) { kit.duplicate(id: item.id, tool: item.tool) },
            ShelfCommand(id: "move-up", title: "Move up", symbol: "arrow.up",
                         enabled: kit.canMovePrompt(id: item.id, by: -1)) { kit.movePrompt(id: item.id, by: -1) },
            ShelfCommand(id: "move-down", title: "Move down", symbol: "arrow.down",
                         enabled: kit.canMovePrompt(id: item.id, by: 1)) { kit.movePrompt(id: item.id, by: 1) },
            ShelfCommand(id: "move-pocket", title: "Move to pocket…", symbol: "folder", enabled: kit.pockets.count > 1 && !kit.isImporting) { [weak self] in self?.moveRequest = PocketMoveRequest(id: item.id, tool: item.tool) },
            ShelfCommand(id: "delete", title: "Delete", symbol: "trash", keys: ["⌘", "⌫"], destructive: true) { kit.delete(id: item.id, tool: item.tool) },
        ]
    }

    func open(_ item: TextShelfItem) {
        selection = item.id
        inspector = .prompt(item.id)
    }

    func edit(_ item: TextShelfItem, kit: PocketLibrary) {
        if let prompt = kit.prompts.first(where: { $0.id == item.id }) { edit(prompt) }
    }

    func showActions(for id: UUID? = nil, kit: PocketLibrary) {
        if let id { selection = id }
        guard let target = resolvedSelection(kit), !commands(for: target, kit: kit).isEmpty else { return }
        selection = target
        actionIndex = 0
        actionsOpen = true
    }

    /// Returns `true` when the key was used, so the panel stops propagating it.
    func handle(_ key: ShelfKey, kit: PocketLibrary) -> Bool {
        guard kit.isLoaded, !kit.isSwitching, archivePresentation == nil, moveRequest == nil, inspector == nil else { return false }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return handleSearch(key, kit: kit) }
        guard tool != .notes else { return false }
        if actionsOpen, let target = resolvedSelection(kit) {
            let commands = commands(for: target, kit: kit)
            switch key {
            case .up: actionIndex = max(0, actionIndex - 1); return true
            case .down: actionIndex = min(commands.count - 1, actionIndex + 1); return true
            case .enter:
                actionsOpen = false
                if commands.indices.contains(actionIndex), commands[actionIndex].enabled { commands[actionIndex].perform() }
                return true
            case .actions: actionsOpen = false; return true
            default: actionsOpen = false
            }
        }
        let ids = ShelfIndex.orderedIDs(tool, kit: kit, query: query)
        guard let current = resolvedSelection(kit), let index = ids.firstIndex(of: current) else {
            return key == .up || key == .down
        }
        let commands = commands(for: current, kit: kit)
        func run(_ id: String) -> Bool {
            guard let command = commands.first(where: { $0.id == id }), command.enabled else { return false }
            command.perform(); return true
        }
        switch key {
        case .up: selection = ids[max(0, index - 1)]; revealRequest = selection; return true
        case .down: selection = ids[min(ids.count - 1, index + 1)]; revealRequest = selection; return true
        case .enter:
            guard let primary = commands.first, primary.enabled else { return false }
            primary.perform(); return true
        case .actions: showActions(kit: kit); return true
        case .open: return run("open")
        case .edit: return run("edit")
        case .duplicate: return run("duplicate")
        case .favorite: return run("favorite")
        case .delete: return query.isEmpty && run("delete")
        }
    }
}
