import SwiftUI

struct TextShelfView: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let items: [TextShelfItem]

    private var filtered: [TextShelfItem] { ShelfIndex.filtered(items, query: model.query) }

    var body: some View {
        if items.isEmpty {
            ShelfEmptyState(symbol: model.tool.symbol,
                title: "Your prompts, close by",
                detail: "Save the prompts, rules and context you reuse. Copy one whenever you need it.",
                actionTitle: "New \(model.tool.itemName)", tool: model.tool, showsNewShortcut: true, action: model.beginNew)
        } else if filtered.isEmpty {
            ShelfEmptyState(symbol: "magnifyingglass", title: "No matches", detail: "Try a different word or clear your search.",
                            actionTitle: "Clear search") { model.query = "" }
        } else {
            let selected = model.resolvedSelection(kit)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        let favorites = filtered.filter(\.favorite)
                        let others = filtered.filter { !$0.favorite }
                        if !favorites.isEmpty {
                            ShelfSection(title: "Favourites", count: favorites.count) {
                                LazyVStack(spacing: 4) { ForEach(favorites) { row($0, selected: selected) } }
                            }
                        }
                        if !others.isEmpty {
                            ShelfSection(title: favorites.isEmpty ? model.tool.title : "In this pocket", count: others.count) {
                                LazyVStack(spacing: 4) { ForEach(others) { row($0, selected: selected) } }
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
                .onAppear { if let id = model.selection { proxy.scrollTo(id) } }
                .onChange(of: model.revealRequest) {
                    guard let id = model.revealRequest else { return }
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func row(_ item: TextShelfItem, selected: UUID?) -> some View {
        ShelfRow(kit: kit, model: model, item: item, selected: selected == item.id, copied: model.lastCopiedID == item.id)
            .id(item.id)
    }
}

private struct ShelfRow: View {
    let kit: PocketLibrary
    let model: PanelModel
    let item: TextShelfItem
    let selected: Bool
    let copied: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var rowWidth: CGFloat = 0

    private var showsInlineActions: Bool { rowWidth >= 320 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ShelfStyle.rowRadius, style: .continuous)
        Button { model.open(item) } label: {
            HStack(alignment: .top, spacing: 12) {
                ItemGlyph(tool: item.tool, symbol: item.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(item.title).font(ShelfStyle.title).lineLimit(1)
                        if item.favorite {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(ShelfStyle.favourite)
                                .accessibilityHidden(true)
                        }
                    }
                    // Keep title width stable as selection/copy feedback changes.
                    // Narrow rows use the footer and context menu instead.
                    .padding(.trailing, showsInlineActions ? 98 : 0)
                    .frame(minHeight: 20, alignment: .leading)
                    Text(item.source).font(.system(size: 12.5)).foregroundStyle(ShelfStyle.secondary)
                        .lineSpacing(1.5).lineLimit(2)
                    if let fields = item.promptTemplate?.fieldNames, !fields.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(fields.prefix(3), id: \.self) { field in
                                Text(SavedTextPreview.readable(field).lowercased())
                                    .font(.system(size: 10.5, weight: .medium))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(item.tool.tint.opacity(0.14), in: Capsule())
                                    .foregroundStyle(ShelfStyle.secondary)
                            }
                            if fields.count > 3 {
                                Text("+\(fields.count - 3)").font(.system(size: 10.5, weight: .medium)).foregroundStyle(ShelfStyle.tertiary)
                            }
                        }
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(selected ? AnyShapeStyle(ShelfStyle.selection.shadow(.drop(color: ShelfStyle.cardShadow, radius: 3, y: 1)))
                                 : AnyShapeStyle(Color.clear), in: shape)
            .overlay {
                if selected { shape.strokeBorder(contrast == .increased ? ShelfStyle.ink : ShelfStyle.hairline, lineWidth: 1) }
            }
            .contentShape(shape)
        }
        .buttonStyle(RowPressStyle())
        .overlay(alignment: .topTrailing) {
            if showsInlineActions, selected || copied {
                accessory.padding(.top, 9).padding(.trailing, 10).transition(.opacity)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { rowWidth = $0 }
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: selected)
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: copied)
        .onHover { if $0 { model.selection = item.id } }
        .shelfPointer()
        .contextMenu {
            ForEach(model.commands(for: item, kit: kit)) { command in
                if command.destructive { Divider() }
                Button(command.title, role: command.destructive ? .destructive : nil, action: command.perform)
                    .disabled(!command.enabled)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityHint(item.fieldCount > 0 ? "Opens the prompt so you can fill in its blanks" : "Opens the complete text")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityActions {
            ForEach(model.commands(for: item, kit: kit).filter(\.enabled)) { command in
                Button(command.title, action: command.perform)
            }
        }
    }

    private var accessory: some View {
        HStack(spacing: 2) {
            if item.fieldCount > 0 {
                RowChip(title: "Fill in", symbol: "curlybraces") { model.open(item) }
            } else {
                RowChip(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc", tint: copied ? ShelfStyle.success : nil,
                        widestTitle: "Copied") {
                    model.copy(item.promptTemplate?.render([:]) ?? item.source, from: item.id)
                }
            }
            RowChip(title: nil, symbol: "ellipsis") { model.showActions(for: item.id, kit: kit) }
                .help("Actions (⌘K)")
        }
        .accessibilityHidden(true) // The row exposes the same commands as named accessibility actions.
    }
}

/// Rows dim slightly on press instead of scaling, so dense lists don't jitter.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Small inline action used inside a highlighted row.
struct RowChip: View {
    let title: String?
    let symbol: String
    var tint: Color? = nil
    /// Widest label this chip shows, reserved so swapping labels never resizes it.
    var widestTitle: String? = nil
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Only the icon animates; the label swaps in place so old and new words never overlap.
                // The new icon scales up from 0.25 while the old one only fades, each keeping its
                // own color, so a stale icon never lingers beside the new label.
                ZStack {
                    Image(systemName: symbol).font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(tint ?? ShelfStyle.secondary)
                        .id(symbol)
                        .transition(.asymmetric(insertion: .scale(scale: 0.25).combined(with: .opacity),
                                                removal: .opacity.animation(reduceMotion ? nil : .easeOut(duration: 0.08))))
                }
                .frame(width: 12)
                .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0), value: symbol)
                if let title {
                    ZStack(alignment: .leading) {
                        if let widestTitle { Text(widestTitle).hidden() }
                        Text(title).transaction { $0.animation = nil }
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                }
            }
            .padding(.horizontal, title == nil ? 6 : 8).frame(height: 22)
            .background(hovered ? ShelfStyle.strong : ShelfStyle.keycap, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
        .shelfPointer()
    }
}

struct SavedTextPreview: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let item: TextShelfItem
    @State private var showReset = false
    @FocusState private var focusedField: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var template: PromptTemplate? { item.promptTemplate }
    private var values: [String: String] { model.fieldValues[item.id] ?? [:] }
    /// `nil` while a template still has blanks, so it can't be copied half-filled.
    private var rendered: String? { template.map { $0.render(values) } ?? item.source }
    private var missing: [String] { template?.missingFields(in: values) ?? [] }
    private var fields: [String] { template?.fieldNames ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label(item.tool.title, systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true)).help("Back (Esc)")
                Spacer(minLength: 0)
                Button { model.edit(item, kit: kit) } label: { Label("Edit", systemImage: "pencil") }
                    .buttonStyle(ShelfButtonStyle(compact: true))
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 12) {
                        ItemGlyph(tool: item.tool, symbol: item.symbol, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(ShelfStyle.display).accessibilityAddTraits(.isHeader)
                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(meta).font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !fields.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(fields, id: \.self) { field in fieldInput(field) }
                            progress
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREVIEW").font(ShelfStyle.eyebrow).tracking(0.7).foregroundStyle(ShelfStyle.secondary)
                        Text(preview).font(ShelfStyle.body).lineSpacing(5)
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .shelfWell(radius: 12)
                }
                .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 22)
            }
            VStack(spacing: 0) {
                Rectangle().fill(ShelfStyle.hairline).frame(height: 1)
                Button { if let rendered { model.copy(rendered, from: item.id) } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: missing.isEmpty ? "doc.on.doc" : "curlybraces")
                        Text(missing.isEmpty ? "Copy \(item.tool.itemName)" : "Fill \(missing.count) more \(missing.count == 1 ? "blank" : "blanks") to copy")
                        Spacer(minLength: 0)
                        if rendered != nil { Keycap("⌘", "↵", inverted: true) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(rendered == nil)
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
        .alert("Reset filled values?", isPresented: $showReset) {
            Button("Reset fields", role: .destructive) { model.fieldValues[item.id] = [:] }
            Button("Keep values", role: .cancel) {}
        } message: { Text("The saved template stays the same.") }
    }

    private var meta: String {
        if !fields.isEmpty { return "Prompt · \(fields.count) \(fields.count == 1 ? "blank" : "blanks")" }
        let words = item.source.split(whereSeparator: \.isWhitespace).count
        return "Prompt · \(words) \(words == 1 ? "word" : "words")"
    }

    private func fieldInput(_ field: String) -> some View {
        let filled = PromptTemplate.isFilled(values[field])
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(Self.readable(field)).font(ShelfStyle.caption.weight(.semibold)).foregroundStyle(ShelfStyle.secondary)
                if fields.filter({ Self.readable($0) == Self.readable(field) }).count > 1 {
                    Text("(\(field))").font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary)
                }
                if filled {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10.5)).foregroundStyle(ShelfStyle.success)
                        .transition(.scale(scale: 0.25).combined(with: .opacity)).accessibilityHidden(true)
                }
            }
            TextField("Enter \(Self.readable(field).lowercased())", text: binding(field), axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...6)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .shelfWell(radius: 9, focused: focusedField == field)
                .accessibilityLabel(fields.filter { Self.readable($0) == Self.readable(field) }.count > 1
                                    ? "\(Self.readable(field)) (\(field))" : Self.readable(field))
        }
        .animation(reduceMotion ? nil : ShelfStyle.pop, value: filled)
    }

    private var progress: some View {
        let done = fields.count - missing.count
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(done) of \(fields.count) filled").font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary).monospacedDigit()
                Spacer()
                Button("Reset") { showReset = true }
                    .buttonStyle(ShelfButtonStyle(compact: true)).disabled(values.values.allSatisfy(\.isEmpty))
            }
            Capsule().fill(ShelfStyle.raised).frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(item.tool.gradient)
                        .scaleEffect(x: fields.isEmpty ? 0 : CGFloat(done) / CGFloat(fields.count), anchor: .leading)
                }
                .animation(reduceMotion ? nil : ShelfStyle.settle, value: done)
                .accessibilityHidden(true)
        }
    }

    private var preview: AttributedString {
        guard let template else { return AttributedString(item.source) }
        return template.preview(values).reduce(into: AttributedString()) { result, segment in
            switch segment {
            case .text(let text): result += AttributedString(text)
            case .value(let text):
                var value = AttributedString(text)
                value.backgroundColor = item.tool.tint.opacity(0.2)
                result += value
            case .missing(let name):
                    var placeholder = AttributedString(" \(Self.readable(name).lowercased()) ")
                    placeholder.foregroundColor = ShelfStyle.secondary
                    placeholder.backgroundColor = ShelfStyle.keycap
                    placeholder.inlinePresentationIntent = .emphasized
                    result += placeholder
            }
        }
    }
    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { model.fieldValues[item.id]?[field] ?? "" }, set: { model.fieldValues[item.id, default: [:]][field] = $0 })
    }
    static func readable(_ name: String) -> String {
        let name = name.replacingOccurrences(of: "_", with: " ")
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
