import SwiftUI

struct PromptsView: View {
    let kit: PocketLibrary
    let model: PanelModel
    private var items: [TextShelfItem] {
        kit.prompts.map { TextShelfItem(id: $0.id, title: $0.label, source: $0.source, favorite: $0.isFavorite, tool: .prompts, promptTemplate: $0.template) }
    }
    var body: some View {
        if case .prompt(let id) = model.inspector, let item = items.first(where: { $0.id == id }) {
            SavedTextPreview(kit: kit, model: model, item: item)
                .transition(.opacity.combined(with: .offset(x: 12)))
        } else {
            TextShelfView(kit: kit, model: model, items: items)
                .transition(.opacity)
        }
    }
}
