import SwiftUI

struct PromptsView: View {
    let kit: PocketLibrary
    let model: PanelModel
    private var items: [TextShelfItem] { ShelfIndex.textItems(.prompts, kit: kit) }
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
