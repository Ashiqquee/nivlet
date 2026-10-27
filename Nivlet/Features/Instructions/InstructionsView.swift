import SwiftUI

struct InstructionsView: View {
    let kit: PocketLibrary
    let model: PanelModel
    private var items: [TextShelfItem] {
        kit.instructions.map { TextShelfItem(id: $0.id, title: $0.label, source: $0.body, favorite: $0.isFavorite, tool: .instructions) }
    }
    var body: some View {
        if case .instruction(let id) = model.inspector, let item = items.first(where: { $0.id == id }) {
            SavedTextPreview(kit: kit, model: model, item: item)
                .transition(.opacity.combined(with: .offset(x: 12)))
        } else {
            TextShelfView(kit: kit, model: model, items: items)
                .transition(.opacity)
        }
    }
}
