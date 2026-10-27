import SwiftUI

struct PanelRootView: View {
    let shell: ShellController
    @Bindable var kit: PocketLibrary
    @Bindable var model: PanelModel
    @FocusState private var searchFocused: Bool
    @Namespace private var toolSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var contentDirection
    @State private var renaming = false
    @State private var pocketName = ""

    var body: some View {
        HStack(spacing: 8) {
            shelf.environment(\.layoutDirection, contentDirection)
            rail.environment(\.layoutDirection, contentDirection)
        }
        // Mirror the two surfaces without recreating their editing state.
        // The action rail always sits toward the centre of the desktop.
        .environment(\.layoutDirection, shell.preferences.edge == .right ? .rightToLeft : .leftToRight)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .font(ShelfStyle.body)
        .foregroundStyle(ShelfStyle.ink)
        .ignoresSafeArea()
        .task { await kit.load() }
        .onChange(of: model.searchFocusRequest) { searchFocused = true }
        .confirmationDialog("Discard your unsaved changes?", isPresented: $model.showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { model.discardDraft() }
            Button("Keep editing", role: .cancel) { model.cancelPendingNavigation() }
        }
        .onChange(of: model.showDiscardConfirmation) {
            if !model.showDiscardConfirmation, model.draft != nil { model.cancelPendingNavigation() }
        }
        .alert("Rename pocket", isPresented: $renaming) {
            TextField("Pocket name", text: $pocketName)
            Button("Rename") { kit.renamePocket(pocketName) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            header
            if model.inspector == nil, model.tool != .notes { search }
            ZStack {
                if !kit.isLoaded {
                    if case .failed = kit.saveState {
                        ShelfEmptyState(symbol: "externaldrive.badge.exclamationmark", title: "Couldn't open the library",
                            detail: "Your saved library hasn't been changed.", actionTitle: "Try again") { Task { await kit.load() } }
                    } else {
                        ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if model.inspector == .editor, let draft = model.draft {
                    TextItemEditor(kit: kit, model: model, draft: draft)
                        .transition(.opacity.combined(with: .offset(x: shell.preferences.edge == .right ? 16 : -16)))
                } else {
                    Group {
                        switch model.tool {
                        case .instructions: InstructionsView(kit: kit, model: model)
                        case .prompts: PromptsView(kit: kit, model: model)
                        case .references: ReferencesView(kit: kit, model: model, importFiles: shell.chooseReferenceFiles)
                        case .notes: NotesView(kit: kit, newTaskRequest: model.newScratchpadTaskRequest)
                        }
                    }
                    .id(model.tool)
                    .transition(.opacity)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .animation(reduceMotion ? nil : ShelfStyle.settle, value: model.inspector)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: model.tool)
            .overlay(alignment: .bottom) { feedback }
            status
        }
        .background(ShelfStyle.canvas, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ShelfStyle.border.opacity(0.4), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Menu {
                Text("Current pocket")
                Button { pocketName = kit.pocketName; renaming = true } label: {
                    Label("Rename pocket…", systemImage: "pencil")
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "folder").foregroundStyle(ShelfStyle.secondary)
                    Text(kit.pocketName).font(ShelfStyle.body.weight(.semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(ShelfStyle.secondary)
                }
                .padding(.vertical, 7).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .help(kit.pocketName)
            .accessibilityLabel("Pocket: \(kit.pocketName)")
            Spacer(minLength: 4)
            Text(model.tool.title).font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)
    }

    private var search: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(ShelfStyle.secondary).accessibilityHidden(true)
            TextField("Search \(model.tool.title.lowercased())", text: $model.query)
                .textFieldStyle(.plain).font(ShelfStyle.body).focused($searchFocused)
                .accessibilityLabel("Search \(model.tool.title.lowercased()) in \(kit.pocketName)")
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(ShelfStyle.secondary).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(searchFocused ? ShelfStyle.focusRing : .clear, lineWidth: 2))
        .padding(.horizontal, 12).padding(.bottom, 10)
    }

    private var rail: some View {
        ViewThatFits(in: .vertical) {
            railContents(compact: false)
            railContents(compact: true)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .contain).accessibilityLabel("Panel tools")
    }

    private func railContents(compact: Bool) -> some View {
        VStack(spacing: compact ? 2 : 4) {
            railButton("Collapse", symbol: shell.preferences.edge == .right ? "chevron.right" : "chevron.left", action: shell.tuck)
            Color.clear.frame(height: compact ? 3 : 7)
            railButton("New \(model.tool == .references ? "reference" : model.tool == .notes ? "to-do" : model.tool.itemName)", symbol: "plus") {
                if model.tool == .references { shell.chooseReferenceFiles() }
                else if model.tool == .notes { model.beginScratchpadTask() }
                else { model.beginNew() }
            }
            .disabled(!kit.isLoaded || kit.isImporting)
            .help("New \(model.tool == .references ? "reference" : model.tool == .notes ? "to-do" : model.tool.itemName) (⌘N)")
            Color.clear.frame(height: compact ? 5 : 10)
            VStack(spacing: compact ? 2 : 4) {
                ForEach(PanelTool.allCases) { tool in
                    Button {
                        withAnimation(reduceMotion ? nil : ShelfStyle.settle) { model.select(tool) }
                    } label: {
                        Label(tool.title, systemImage: tool.symbol)
                            .font(.system(size: 17, weight: .regular))
                            .frame(width: 22, height: 27)
                            .background {
                                if model.tool == tool {
                                    RoundedRectangle(cornerRadius: 10).fill(ShelfStyle.hover)
                                        .padding(.horizontal, -5).padding(.vertical, -2)
                                        .matchedGeometryEffect(id: compact ? "compactTool" : "selectedTool", in: toolSelection)
                                }
                            }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(ShelfButtonStyle(compact: true))
                    .keyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: .command)
                    .help("\(tool.title) (⌘\(String(tool.shortcut)))")
                    .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
                }
            }
            Color.clear.frame(height: compact ? 5 : 10)
            VStack(spacing: compact ? 2 : 4) {
                railButton(shell.isPinned ? "Unpin panel" : "Pin panel", symbol: shell.isPinned ? "pin.fill" : "pin") { shell.isPinned.toggle() }
                    .accessibilityValue(shell.isPinned ? "Pinned" : "Unpinned")
                Menu {
                    Toggle("Full height", isOn: Binding(get: { shell.preferences.fullHeight }, set: shell.setFullHeight))
                    Picker("Screen edge", selection: Binding(get: { shell.preferences.edge }, set: shell.setEdge)) {
                        ForEach(ScreenEdge.allCases) { edge in Text(edge.title).tag(edge) }
                    }
                    Button("Reset panel size", action: shell.resetPanelSize)
                    Divider()
                    Button("Quit Nivlet") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .frame(width: 22, height: 25)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .frame(width: 34, height: 35)
                .accessibilityLabel("Panel settings").help("Panel settings")
            }
        }
        .padding(.horizontal, 7).padding(.vertical, compact ? 8 : 10)
        .frame(width: 50)
        .background(ShelfStyle.chrome, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ShelfStyle.border.opacity(0.4), lineWidth: 1))
    }

    private func railButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 16)).frame(width: 22, height: 25)
        }
        .labelStyle(.iconOnly).buttonStyle(ShelfButtonStyle(compact: true)).help(title)
    }

    private var status: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch kit.saveState {
            case .loading:
                Text("Opening library…")
            case .saving:
                Text("Saving…")
            case .saved:
                Image(systemName: "checkmark").font(.system(size: 10, weight: .medium)).accessibilityHidden(true)
                Text(kit.isImporting ? "Importing…" : "Saved locally")
            case .preview:
                Text("Preview pocket · not saved")
            case .failed(let message):
                Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                Text(message).fixedSize(horizontal: false, vertical: true)
                Button("Retry") { Task { if kit.isLoaded { await kit.flush() } else { await kit.load() } } }
                    .buttonStyle(ShelfButtonStyle(compact: true))
            }
            Spacer(minLength: 0)
            if kit.canUndoDelete {
                Button("Undo delete") { kit.undoDelete() }.buttonStyle(ShelfButtonStyle(compact: true))
            }
        }
        .font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder private var feedback: some View {
        if let message = model.feedback {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: model.isFeedbackError ? "exclamationmark.circle" : "checkmark.circle")
                Text(message).fixedSize(horizontal: false, vertical: true)
                if model.isFeedbackError {
                    Button { model.dismissFeedback() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless).accessibilityLabel("Dismiss message")
                }
            }
            .font(ShelfStyle.body).padding(12).background(ShelfStyle.chrome, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ShelfStyle.border))
            .padding(10).transition(.opacity.combined(with: .offset(y: 6)))
            .accessibilityHidden(!model.isFeedbackError)
        }
    }
}
