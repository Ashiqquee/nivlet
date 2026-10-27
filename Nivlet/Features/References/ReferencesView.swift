import AppKit
import SwiftUI

struct ReferencesView: View {
    let kit: PocketLibrary
    @Bindable var model: PanelModel
    let importFiles: () -> Void
    @State private var dropTarget = false

    private var filtered: [ReferenceItem] {
        guard !model.query.isEmpty else { return kit.references }
        return kit.references.filter { $0.label.localizedStandardContains(model.query) || $0.note.localizedStandardContains(model.query) }
    }

    var body: some View {
        Group {
            if case .reference(let id) = model.inspector, let reference = kit.references.first(where: { $0.id == id }) {
                ReferenceInspector(kit: kit, reference: reference, model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if kit.references.isEmpty {
                ShelfEmptyState(symbol: "photo.on.rectangle.angled", title: "A shelf for your references",
                    detail: "Drop images or files here. Your originals stay untouched.", actionTitle: "Add files", action: importFiles)
            } else if filtered.isEmpty {
                ShelfEmptyState(symbol: "magnifyingglass", title: "No matches", detail: "Try a different word or clear your search.", actionTitle: "Clear search") { model.query = "" }
            } else {
                ScrollView {
                    ShelfSection(title: "References", count: filtered.count) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], alignment: .leading, spacing: 12) {
                            ForEach(filtered) { reference in
                                ReferenceTile(kit: kit, reference: reference, model: model)
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 10)
                }
            }
        }
        .overlay {
            if dropTarget {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .padding(7).allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !kit.isPreview else { return false }
            Task {
                let failures = await kit.importFiles(urls)
                if !failures.isEmpty { model.showFeedback(failures.joined(separator: "\n"), isError: true) }
            }
            return true
        } isTargeted: { dropTarget = $0 }
    }
}

private struct ReferenceTile: View {
    let kit: PocketLibrary
    let reference: ReferenceItem
    let model: PanelModel
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { model.inspector = .reference(reference.id) } label: {
                ZStack(alignment: .bottomTrailing) {
                    GeometryReader { geometry in
                        ReferenceMedia(reference: reference, thumbnail: true)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                        .aspectRatio(1, contentMode: .fit)
                        .background(ShelfStyle.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .medium)).padding(7)
                        .background(ShelfStyle.chrome, in: RoundedRectangle(cornerRadius: 7))
                        .padding(7).opacity(hovered ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ShelfStyle.border.opacity(hovered ? 0.7 : 0.25)))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .shelfPointer(.openHand)
            .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }
            .accessibilityLabel("Preview \(reference.label)")
            .help("Open preview, or drag a copy of the original file")
            Text(reference.label).font(ShelfStyle.body.weight(.medium)).lineLimit(1).help(reference.label)
            Text(reference.displayName).font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary).lineLimit(1)
                .help(reference.displayName)
        }
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
        .contextMenu {
            Button("Preview") { model.inspector = .reference(reference.id) }
            Button("Reveal in Finder") { ReferenceActions.reveal(reference, model: model) }
            Button("Copy note") { model.copy(reference.note) }.disabled(reference.note.isEmpty)
            Divider()
            Button("Delete", role: .destructive) { kit.delete(id: reference.id, tool: .references) }
        }
    }
}

private struct ReferenceInspector: View {
    let kit: PocketLibrary
    let reference: ReferenceItem
    let model: PanelModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label("References", systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true)).help("Back (Esc)")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(reference.label).font(.system(size: 16, weight: .semibold)).accessibilityAddTraits(.isHeader)
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        ReferenceMedia(reference: reference, thumbnail: false)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(150, geometry.size.height - 220))
                            .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }
                            .shelfPointer(.openHand)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Note").font(ShelfStyle.body.weight(.medium))
                            TextField("Add a note…", text: Binding(get: { current.note }, set: { kit.updateReference(id: reference.id, note: $0) }), axis: .vertical)
                                .textFieldStyle(.roundedBorder).lineLimit(2...8).accessibilityLabel("Reference note")
                        }
                        Text(reference.displayName).font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary)
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 14)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { drag; copy; reveal }
                VStack(alignment: .leading, spacing: 7) { drag; HStack { copy; reveal } }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var current: ReferenceItem { kit.references.first(where: { $0.id == reference.id }) ?? reference }
    private var drag: some View {
        Label("Drag file", systemImage: "hand.draw").font(ShelfStyle.body.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 8)
            .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 9))
            .onDrag { ReferenceActions.dragProvider(for: reference, model: model) }.shelfPointer(.openHand)
            .help("Drag a copy into another app; check the upload there")
            .accessibilityHidden(true) // Equivalent keyboard action: Reveal in Finder.
    }
    private var copy: some View {
        Button("Copy note") { model.copy(current.note) }.buttonStyle(ShelfButtonStyle(compact: true)).disabled(current.note.isEmpty)
    }
    private var reveal: some View {
        Button { ReferenceActions.reveal(reference, model: model) } label: { Image(systemName: "folder") }
            .buttonStyle(ShelfButtonStyle(compact: true)).accessibilityLabel("Reveal in Finder").help("Reveal a copy in Finder")
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
            } else if case .text(let text) = content, !thumbnail {
                ScrollView {
                    Text(text).font(.system(size: 13, design: .monospaced)).lineSpacing(4).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: reference.isImage ? "photo" : "doc.text").font(.system(size: 30, weight: .light))
                    if !thumbnail { Text("Use Reveal in Finder to view the full file.").font(ShelfStyle.body).multilineTextAlignment(.center) }
                }
                .foregroundStyle(ShelfStyle.secondary).padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
        .task(id: reference.originalURL) {
            let loaded = await ReferencePreviewLoader.load(reference.originalURL, image: reference.isImage, maxPixels: thumbnail ? 480 : 1200)
            guard !Task.isCancelled else { return }
            content = loaded
            if case .image(let data) = loaded { image = NSImage(data: data) }
        }
        .accessibilityLabel("Preview of \(reference.label)")
    }
}
