import AppKit
import SwiftUI

struct ReferencesView: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let importFiles: () -> Void
    let retryImport: (UUID) -> Void
    @State private var dropTarget = false

    private var filtered: [ReferenceItem] { ShelfIndex.references(kit: kit, query: model.query) }

    var body: some View {
        VStack(spacing: 0) {
            if !kit.importResults.isEmpty { ReferenceImportResults(kit: kit, chooseAgain: retryImport).layoutPriority(1) }
            content
        }
    }

    private var content: some View {
        Group {
            if case .reference(let id) = model.inspector, let reference = kit.references.first(where: { $0.id == id }) {
                ReferenceInspector(kit: kit, reference: reference, model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if kit.references.isEmpty {
                ShelfEmptyState(symbol: PanelTool.references.symbol, title: "Add your first reference",
                    detail: "Keep original files close. Add, drop or paste a file.", actionTitle: "Add files",
                    tool: .references, showsNewShortcut: true, action: importFiles)
            } else if filtered.isEmpty {
                ShelfEmptyState(symbol: "magnifyingglass", title: "No matches", detail: "Try a different word or clear your search.", actionTitle: "Clear search") { model.query = "" }
            } else {
                let selected = model.resolvedSelection(kit)
                ScrollViewReader { proxy in
                    ScrollView {
                        ShelfSection(title: "References", count: filtered.count) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 14) {
                                ForEach(filtered) { reference in
                                    ReferenceTile(kit: kit, reference: reference, model: model, selected: selected == reference.id)
                                        .id(reference.id)
                                }
                            }
                            .padding(.horizontal, 6)
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
        .overlay {
            if dropTarget {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(PanelTool.references.tint.opacity(0.08))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PanelTool.references.tint, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    Label("Drop to add a copy", systemImage: "arrow.down.doc.fill")
                        .shelfFont(.body, weight: .semibold).foregroundStyle(PanelTool.references.tint)
                }
                .padding(8).allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !kit.isPreview, !kit.isImporting, urls.allSatisfy(\.isFileURL) else { return false }
            Task { await kit.importFiles(urls) }
            return true
        } isTargeted: { dropTarget = $0 }
    }
}

private struct ReferenceTile: View {
    let kit: PocketLibrary
    let reference: ReferenceItem
    let model: PanelModel
    let selected: Bool
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 7) {
            Button { model.inspector = .reference(reference.id) } label: {
                GeometryReader { geometry in
                    ReferenceMedia(reference: reference, thumbnail: true)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .aspectRatio(1, contentMode: .fit)
                .background(ShelfStyle.raised)
                .clipShape(shape)
                .overlay(shape.strokeBorder(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .shelfFont(size: 10, weight: .bold).foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .padding(7).opacity(hovered ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(PanelTool.references.tint, lineWidth: 2).opacity(selected ? 1 : 0)
                }
                .shadow(color: .black.opacity(hovered ? 0.25 : 0), radius: 10, y: 5)
                .scaleEffect(hovered && !reduceMotion ? 1.02 : 1)
                .contentShape(shape)
            }
            .buttonStyle(RowPressStyle())
            .shelfPointer()
            .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }
            .accessibilityLabel("Preview \(reference.label)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help("Open preview, or drag a copy of the original file")
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(reference.label).shelfFont(size: 12.5, weight: .semibold).lineLimit(1).help(reference.label)
                    if reference.isFavorite { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(ShelfStyle.favourite).accessibilityLabel("Favourite") }
                }
                Text(reference.displayName).shelfFont(.caption).foregroundStyle(ShelfStyle.secondary).lineLimit(1)
                    .help(reference.displayName)
                if kit.referenceIsPending(reference.id) {
                    Label("Not saved", systemImage: "exclamationmark.triangle").shelfFont(.caption).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 4)
        }
        .onHover { hovered = $0; if $0 { model.selection = reference.id } }
        .animation(reduceMotion ? nil : ShelfStyle.pop, value: hovered)
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: selected)
        .task(id: selected) { if selected { await ReferenceActions.prepare(reference, model: model) } }
        .contextMenu {
            ForEach(model.commands(for: reference.id, kit: kit)) { command in
                if command.destructive { Divider() }
                Button(command.title, role: command.destructive ? .destructive : nil, action: command.perform)
                    .disabled(!command.enabled)
            }
        }
    }
}

private struct ReferenceInspector: View {
    let kit: PocketLibrary
    let reference: ReferenceItem
    let model: PanelModel
    @FocusState private var noteFocused: Bool
    @FocusState private var labelFocused: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label("References", systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true)).help("Back (Esc)")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Label").shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
                            TextField("Reference label", text: Binding(get: { current.label }, set: { kit.renameReference(id: reference.id, label: $0) }), axis: .vertical)
                                .textFieldStyle(.plain).shelfFont(.display).focused($labelFocused)
                                .accessibilityLabel("Reference label")
                            Text(reference.displayName).shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
                                .textSelection(.enabled).lineLimit(2)
                        }
                        ReferenceMedia(reference: reference, thumbnail: false)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(150, geometry.size.height - 230))
                            .background(ShelfStyle.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1))
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                            .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }
                            .shelfPointer(.openHand)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note").shelfFont(.caption, weight: .semibold).foregroundStyle(ShelfStyle.secondary)
                            TextField("Add a note…", text: Binding(get: { current.note }, set: { kit.updateReference(id: reference.id, note: $0) }), axis: .vertical)
                                .textFieldStyle(.plain).lineLimit(2...8)
                                .focused($noteFocused)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .shelfWell(radius: 9, focused: noteFocused)
                                .accessibilityLabel("Reference note")
                        }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { drag; Spacer(minLength: 0); copyFile; copy; reveal }
                VStack(alignment: .leading, spacing: 7) { drag; HStack { copyFile; copy; reveal } }
            }
            .padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(ShelfStyle.hairline).frame(height: 1) }
        }
        .onChange(of: noteFocused) { if !noteFocused { kit.flushSoon() } }
        .onChange(of: labelFocused) { if !labelFocused { kit.flushSoon() } }
        .task(id: reference.id) { await ReferenceActions.prepare(reference, model: model) }
    }
    private var current: ReferenceItem { kit.references.first(where: { $0.id == reference.id }) ?? reference }
    private var drag: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw.fill").foregroundStyle(PanelTool.references.tint)
            Text("Drag file")
        }
        .shelfFont(.body, weight: .semibold).padding(.horizontal, 12).padding(.vertical, 8)
        .background(PanelTool.references.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(PanelTool.references.tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }.shelfPointer(.openHand)
        .help("Drag a copy into another app; check the upload there")
        .accessibilityHidden(true) // Equivalent keyboard action: Reveal in Finder.
    }
    private var copyFile: some View {
        Button { ReferenceActions.copyFile(reference, model: model) } label: { Label("Copy file", systemImage: "doc.on.clipboard") }
            .buttonStyle(ShelfButtonStyle(filled: true, compact: true))
            .help("Copy the file to paste into another app")
    }
    private var copy: some View {
        Button { model.copy(current.note, from: reference.id) } label: { Label("Copy note", systemImage: "doc.on.doc") }
            .buttonStyle(ShelfButtonStyle(filled: true, compact: true)).disabled(current.note.isEmpty)
    }
    private var reveal: some View {
        Button { ReferenceActions.reveal(reference, model: model) } label: { Image(systemName: "folder") }
            .buttonStyle(ShelfButtonStyle(filled: true, compact: true)).accessibilityLabel("Reveal in Finder").help("Reveal a copy in Finder")
    }
}

private struct ReferenceMedia: View {
    let reference: ReferenceItem
    let thumbnail: Bool
    @State private var content: ReferencePreviewContent?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                if thumbnail { Image(nsImage: image).resizable().scaledToFill() }
                else { Image(nsImage: image).resizable().scaledToFit() }
            } else if case .text(let text, let truncated) = content, !thumbnail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                    if truncated { Text("Preview limited to 32 KB. The original file is unchanged.").shelfFont(.caption).foregroundStyle(ShelfStyle.secondary) }
                    Text(text).shelfFont(size: 12.5, design: .monospaced).lineSpacing(4).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: reference.isImage ? "photo" : "doc.text").font(.system(size: thumbnail ? 26 : 30, weight: .light))
                        .foregroundStyle(PanelTool.references.tint)
                    if !thumbnail { Text("Use Reveal in Finder to view the full file.").shelfFont(.body).multilineTextAlignment(.center) }
                }
                .foregroundStyle(ShelfStyle.secondary).padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
        .task(id: reference.id) {
            content = nil; image = nil
            let loaded = await ReferencePreviewLoader.load(reference.originalURL, image: reference.isImage, maxPixels: thumbnail ? 480 : 1200, displayName: reference.displayName)
            guard !Task.isCancelled else { return }
            content = loaded
            if case .image(let data) = loaded { image = NSImage(data: data) }
        }
        .accessibilityLabel("Preview of \(reference.label)")
    }
}
