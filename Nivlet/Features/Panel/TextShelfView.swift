import SwiftUI

struct TextShelfItem: Identifiable {
    let id: UUID
    let title: String
    let source: String
    let favorite: Bool
    let tool: PanelTool
    var promptTemplate: PromptTemplate? = nil
    var fieldCount: Int { promptTemplate?.fieldNames.count ?? 0 }
}

struct TextShelfView: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let items: [TextShelfItem]

    private var filtered: [TextShelfItem] {
        guard !model.query.isEmpty else { return items }
        return items.filter { $0.title.localizedStandardContains(model.query) || $0.source.localizedStandardContains(model.query) }
    }

    var body: some View {
        if items.isEmpty {
            ShelfEmptyState(symbol: model.tool.symbol,
                title: model.tool == .prompts ? "Your prompts, close by" : "Keep your instructions here",
                detail: model.tool == .prompts ? "Save a prompt you use. Copy it whenever you need it." : "Save the rules and context you use across projects.",
                actionTitle: "New \(model.tool.itemName)", action: model.beginNew)
        } else if filtered.isEmpty {
            ShelfEmptyState(symbol: "magnifyingglass", title: "No matches", detail: "Try a different word or clear your search.",
                            actionTitle: "Clear search") { model.query = "" }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    let favorites = filtered.filter(\.favorite)
                    let others = filtered.filter { !$0.favorite }
                    if !favorites.isEmpty {
                        ShelfSection(title: "Favourites", count: favorites.count) {
                            LazyVStack(spacing: 8) { ForEach(favorites) { row($0) } }
                        }
                    }
                    if !others.isEmpty {
                        ShelfSection(title: favorites.isEmpty ? model.tool.title : "In this pocket", count: others.count) {
                            LazyVStack(spacing: 8) { ForEach(others) { row($0) } }
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
    }

    private func row(_ item: TextShelfItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { open(item) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if item.favorite {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(ShelfStyle.secondary)
                                .accessibilityHidden(true)
                        }
                        Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward").font(.system(size: 9, weight: .medium)).foregroundStyle(ShelfStyle.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(item.source).font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary)
                        .lineSpacing(4).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2).contentShape(Rectangle())
            }
            .buttonStyle(.plain).shelfPointer()
            .accessibilityLabel("Open \(item.title)").accessibilityHint("Opens the complete text")

            HStack(spacing: 2) {
                Spacer(minLength: 0)
                if item.fieldCount > 0 {
                    Button { open(item) } label: { Label("Fill in", systemImage: "curlybraces") }
                        .buttonStyle(ShelfButtonStyle(compact: true))
                        .accessibilityLabel("Fill \(item.fieldCount) fields in \(item.title)")
                } else {
                    Button { model.copy(copyText(item)) } label: { Label("Copy", systemImage: "doc.on.doc") }
                        .buttonStyle(ShelfButtonStyle(compact: true))
                        .accessibilityLabel("Copy \(item.title)")
                }
                Menu {
                    Button("Edit…") { edit(item) }
                    Button("Duplicate") { kit.duplicate(id: item.id, tool: item.tool) }
                    Divider()
                    Button("Delete", role: .destructive) { kit.delete(id: item.id, tool: item.tool) }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .accessibilityLabel("Actions for \(item.title)")
            }
            .foregroundStyle(ShelfStyle.secondary)
        }
        .padding(12).shelfCard()
        .contextMenu {
            Button("Open") { open(item) }
            Button("Edit…") { edit(item) }
            Button(item.favorite ? "Remove favourite" : "Add favourite") { kit.toggleFavorite(id: item.id, tool: item.tool) }
            Button("Duplicate") { kit.duplicate(id: item.id, tool: item.tool) }
            Divider()
            Button("Delete", role: .destructive) { kit.delete(id: item.id, tool: item.tool) }
        }
    }

    private func copyText(_ item: TextShelfItem) -> String {
        item.promptTemplate?.render([:]) ?? item.source
    }
    private func open(_ item: TextShelfItem) {
        model.inspector = item.tool == .prompts ? .prompt(item.id) : .instruction(item.id)
    }
    private func edit(_ item: TextShelfItem) {
        if item.tool == .prompts, let prompt = kit.prompts.first(where: { $0.id == item.id }) { model.edit(prompt) }
        if item.tool == .instructions, let instruction = kit.instructions.first(where: { $0.id == item.id }) { model.edit(instruction) }
    }
}

struct SavedTextPreview: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let item: TextShelfItem
    @State private var showReset = false

    private var template: PromptTemplate? { item.promptTemplate }
    private var values: [String: String] { model.fieldValues[item.id] ?? [:] }
    private var rendered: String? { item.tool == .instructions ? item.source : template?.render(values) }
    private var missing: [String] { template?.missingFields(in: values) ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label(item.tool.title, systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true)).help("Back (Esc)")
                Spacer(minLength: 0)
                Button("Edit") { edit() }.buttonStyle(ShelfButtonStyle(compact: true))
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(item.title).font(.system(size: 17, weight: .semibold)).accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    if let template, !template.fieldNames.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(template.fieldNames, id: \.self) { field in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(Self.readable(field)).font(ShelfStyle.body.weight(.medium))
                                    TextField("Enter \(Self.readable(field).lowercased())", text: binding(field), axis: .vertical)
                                        .textFieldStyle(.roundedBorder).lineLimit(1...6)
                                        .accessibilityLabel(Self.readable(field))
                                }
                            }
                            HStack {
                                Text("Preview").font(ShelfStyle.body.weight(.medium)).foregroundStyle(ShelfStyle.secondary)
                                Spacer()
                                Button("Reset fields") { showReset = true }
                                    .buttonStyle(ShelfButtonStyle(compact: true)).disabled(values.values.allSatisfy(\.isEmpty))
                            }
                        }
                    }
                    Text(preview).font(ShelfStyle.body).lineSpacing(5)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
            VStack(spacing: 8) {
                if !missing.isEmpty {
                    Text("\(missing.count) \(missing.count == 1 ? "field" : "fields") left")
                        .font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary)
                }
                Button { if let rendered { model.copy(rendered) } } label: {
                    Label("Copy \(item.tool.itemName)", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .buttonStyle(ShelfButtonStyle(filled: true)).disabled(rendered == nil)
            }
            .padding(12)
        }
        .alert("Reset filled values?", isPresented: $showReset) {
            Button("Reset fields", role: .destructive) { model.fieldValues[item.id] = [:] }
            Button("Keep values", role: .cancel) {}
        } message: { Text("The saved template stays the same.") }
    }

    private var preview: AttributedString {
        guard let template else { return AttributedString(item.source) }
        return template.segments.reduce(into: AttributedString()) { result, segment in
            switch segment {
            case .text(let text): result += AttributedString(text)
            case .field(let name):
                if PromptTemplate.isFilled(values[name]) { result += AttributedString(values[name]!) }
                else {
                    var placeholder = AttributedString("[\(Self.readable(name).lowercased())]")
                    placeholder.foregroundColor = ShelfStyle.secondary
                    placeholder.inlinePresentationIntent = .emphasized
                    result += placeholder
                }
            }
        }
    }
    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { model.fieldValues[item.id]?[field] ?? "" }, set: { model.fieldValues[item.id, default: [:]][field] = $0 })
    }
    private func edit() {
        if item.tool == .prompts, let value = kit.prompts.first(where: { $0.id == item.id }) { model.edit(value) }
        if item.tool == .instructions, let value = kit.instructions.first(where: { $0.id == item.id }) { model.edit(value) }
    }
    static func readable(_ name: String) -> String {
        let name = name.replacingOccurrences(of: "_", with: " ")
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
