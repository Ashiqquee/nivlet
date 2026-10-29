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
    @State private var pocketHovered = false
    @State private var showingPinFeedback = false

    private var isListMode: Bool { kit.isLoaded && model.inspector == nil && model.tool != .notes }

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
        .onChange(of: model.tool) { kit.flushSoon() }
        .onChange(of: searchFocused) { if searchFocused { kit.flushSoon() } }
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

    // MARK: Shelf

    private var shelf: some View {
        VStack(spacing: 0) {
            if model.inspector == nil {
                header
                if model.tool != .notes { search }
            } else {
                Color.clear.frame(height: 14)
            }
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
                        case .prompts: PromptsView(kit: kit, model: model)
                        case .references: ReferencesView(kit: kit, model: model, importFiles: shell.chooseReferenceFiles,
                                                        retryImport: shell.chooseReferenceFileForRetry)
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
            if showsFooter { footer }
        }
        .overlay { actionsLayer }
        .overlay(alignment: .bottom) {
            // Scoped to the toast: a shelf-wide animation also cross-faded and resized row chips.
            if model.tool != .notes {
                feedback.padding(.bottom, showsFooter ? 58 : 76)
                    .animation(reduceMotion ? nil : ShelfStyle.pop, value: model.feedback)
            }
        }
        .animation(reduceMotion ? nil : ShelfStyle.pop, value: model.actionsOpen)
        .panelSurface(dockedEdge: dockedEdge)
    }

    /// A full-height shelf is docked flush to the display edge. The shelf keeps
    /// its own text direction, so the left screen edge is its leading side.
    private var dockedEdge: HorizontalEdge? {
        guard shell.preferences.fullHeight else { return nil }
        let leftToRight = contentDirection == .leftToRight
        return (shell.preferences.edge == .left) == leftToRight ? .leading : .trailing
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            headerRow(compact: false)
            headerRow(compact: true)
        }
        .padding(.leading, 18).padding(.trailing, 14).padding(.top, 18).padding(.bottom, 14)
        .animation(reduceMotion ? nil : ShelfStyle.pop, value: model.tool)
    }

    private func headerRow(compact: Bool) -> some View {
        HStack(spacing: 10) {
            ToolTile(tool: model.tool, size: 30)
                .id(model.tool)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 1) {
                Text(model.tool.title).font(ShelfStyle.heading).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle).font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary).lineLimit(1)
                    .contentTransition(.numericText())
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 6)
            pocketMenu(compact: compact)
                .fixedSize()
        }
    }

    private var subtitle: String {
        func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
        guard kit.isLoaded else { return "Opening…" }
        return switch model.tool {
        case .prompts: count(kit.prompts.count, "prompt")
        case .references: count(kit.references.count, "file")
        case .notes: "Notes and to-dos"
        }
    }

    private func pocketMenu(compact: Bool) -> some View {
        Menu {
            Text("Current pocket")
            Button { pocketName = kit.pocketName; renaming = true } label: {
                Label("Rename pocket…", systemImage: "pencil")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: 10.5)).foregroundStyle(ShelfStyle.secondary)
                if !compact {
                    Text(kit.pocketName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .frame(maxWidth: 120)
                }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(ShelfStyle.secondary)
            }
            .padding(.horizontal, 10).frame(height: 28)
            .background(pocketHovered ? ShelfStyle.keycap : ShelfStyle.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(ShelfStyle.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        // A button-style menu keeps the whole custom pill (icon, name, chevron) as its label.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onHover { pocketHovered = $0 }
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: pocketHovered)
        .shelfPointer()
        .help(kit.pocketName)
        .accessibilityLabel("Pocket: \(kit.pocketName)")
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12.5, weight: .medium)).foregroundStyle(ShelfStyle.secondary)
                .accessibilityHidden(true)
            TextField("Search \(model.tool.title.lowercased())…", text: $model.query)
                .textFieldStyle(.plain).font(.system(size: 13.5)).focused($searchFocused)
                .accessibilityLabel("Search \(model.tool.title.lowercased()) in \(kit.pocketName)")
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(ShelfStyle.secondary).accessibilityLabel("Clear search")
                    .shelfPointer()
            } else if !searchFocused {
                Keycap("⌘", "F")
            }
        }
        .padding(.horizontal, 12).frame(height: 38)
        .shelfWell(radius: 10, focused: searchFocused)
        .padding(.horizontal, 14).padding(.bottom, 10)
    }

    // MARK: Footer action bar

    private var showsFooter: Bool {
        if case .failed = kit.saveState { return true }
        return model.inspector == nil && kit.isLoaded
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(ShelfStyle.hairline).frame(height: 1)
            if case .failed(let message) = kit.saveState {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Retry") { Task { if kit.isLoaded { await kit.retrySaving() } else { await kit.load() } } }
                        .buttonStyle(ShelfButtonStyle(filled: true, compact: true))
                }
                .font(ShelfStyle.caption).padding(.horizontal, 16).padding(.vertical, 12)
            } else if model.tool == .notes, let message = model.feedback {
                // Feedback participates in layout so it cannot cover task input.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if model.isFeedbackError {
                        Button { model.dismissFeedback() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).accessibilityLabel("Dismiss message")
                    }
                }
                .font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary)
                .padding(.horizontal, 18).padding(.vertical, 8)
            } else {
                ViewThatFits(in: .horizontal) {
                    footerBar(showsStatus: true, showsPrimary: true)
                    footerBar(showsStatus: false, showsPrimary: true)
                    footerBar(showsStatus: false, showsPrimary: true, compactPrimary: true)
                    footerBar(showsStatus: false, showsPrimary: false)
                }
                .padding(.horizontal, 12).frame(height: model.tool == .notes ? 30 : 48)
            }
        }
        .background(ShelfStyle.raised.opacity(0.6))
    }

    private func footerBar(showsStatus: Bool, showsPrimary: Bool, compactPrimary: Bool = false) -> some View {
        HStack(spacing: 6) {
            status(showsText: showsStatus)
            Spacer(minLength: 6)
            if isListMode, let id = model.resolvedSelection(kit) {
                let commands = model.commands(for: id, kit: kit)
                if showsPrimary, let primary = commands.first {
                    Button(action: primary.perform) {
                        HStack(spacing: 7) { Text(compactPrimary ? primary.compactTitle : primary.title).lineLimit(1); Keycap("↵") }
                    }
                    .buttonStyle(ShelfButtonStyle(compact: true))
                    .accessibilityLabel(primary.title)
                    .disabled(!primary.enabled)
                    Rectangle().fill(ShelfStyle.hairline).frame(width: 1, height: 16)
                }
                Button { model.showActions(kit: kit) } label: {
                    HStack(spacing: 7) { Text("Actions").fixedSize(); Keycap("⌘", "K") }
                }
                .buttonStyle(ShelfButtonStyle(compact: true))
                .accessibilityLabel("Actions for selected item")
            }
        }
    }

    /// Words only when they tell the person something. A quiet, saved list shows
    /// nothing; Scratchpad keeps its save confirmation because it autosaves typing.
    @ViewBuilder private func status(showsText: Bool) -> some View {
        HStack(spacing: 6) {
            if kit.canUndoDelete {
                Button { kit.undoDelete() } label: {
                    HStack(spacing: 6) { Image(systemName: "arrow.uturn.backward"); Text("Undo delete") }
                }
                .buttonStyle(ShelfButtonStyle(compact: true))
            } else if showsText {
                switch kit.saveState {
                case .loading:
                    ProgressView().controlSize(.mini).accessibilityHidden(true)
                    Text("Opening…")
                case .saving:
                    ProgressView().controlSize(.mini).accessibilityHidden(true)
                    Text("Saving…")
                case .saved:
                    if kit.isImporting {
                        ProgressView().controlSize(.mini).accessibilityHidden(true)
                        Text("Importing…")
                    } else if model.tool == .notes {
                        Text("Saved")
                    }
                case .preview:
                    Text("Preview · not saved")
                case .failed:
                    EmptyView()
                }
            }
        }
        .font(ShelfStyle.caption).foregroundStyle(ShelfStyle.secondary)
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions panel (⌘K)

    @ViewBuilder private var actionsLayer: some View {
        if model.actionsOpen, let id = model.resolvedSelection(kit) {
            let commands = model.commands(for: id, kit: kit)
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.12)
                    .contentShape(Rectangle())
                    .onTapGesture { model.actionsOpen = false }
                    .accessibilityHidden(true)
                ActionsPanel(model: model, commands: commands)
                    .padding(.trailing, 12).padding(.bottom, 54)
                    .transition(.scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }

    // MARK: Rail

    private var rail: some View {
        ViewThatFits(in: .vertical) {
            railContents(compact: false)
            railContents(compact: true)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .contain).accessibilityLabel("Panel tools")
    }

    private func railContents(compact: Bool) -> some View {
        let size: CGFloat = compact ? 32 : 36
        let newTitle = "New \(model.tool == .references ? "reference" : model.tool == .notes ? "to-do" : model.tool.itemName)"
        return VStack(spacing: compact ? 2 : 4) {
            railButton("Collapse", symbol: shell.preferences.edge == .right ? "chevron.right" : "chevron.left", size: size, action: shell.tuck)
            Color.clear.frame(height: compact ? 2 : 6)
            Button {
                if model.tool == .references { shell.chooseReferenceFiles() }
                else if model.tool == .notes { model.beginScratchpadTask() }
                else { model.beginNew() }
            } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).frame(width: size, height: size)
            }
            .buttonStyle(RailButtonStyle(resting: ShelfStyle.raised))
            .disabled(!kit.isLoaded || kit.isImporting)
            .help("\(newTitle) (⌘N)")
            .accessibilityLabel(newTitle)
            Color.clear.frame(height: compact ? 4 : 8)
            VStack(spacing: compact ? 2 : 4) {
                ForEach(PanelTool.allCases) { tool in
                    let selected = model.tool == tool
                    Button {
                        withAnimation(reduceMotion ? nil : ShelfStyle.pop) { model.select(tool) }
                    } label: {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(ShelfStyle.secondary))
                            .frame(width: size, height: size)
                            .background {
                                if selected {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(tool.gradient)
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
                                        .shadow(color: tool.tint.opacity(0.5), radius: 7, y: 2)
                                        .matchedGeometryEffect(id: compact ? "compactTool" : "selectedTool", in: toolSelection)
                                }
                            }
                    }
                    .buttonStyle(RailButtonStyle(selected: selected))
                    .keyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: .command)
                    .help("\(tool.title) (⌘\(String(tool.shortcut)))")
                    .accessibilityLabel(tool.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Color.clear.frame(height: compact ? 4 : 8)
            Button {
                shell.isPinned.toggle()
                showingPinFeedback = true
            } label: {
                ZStack {
                    Image(systemName: shell.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(showingPinFeedback ? 0 : 1)
                    if showingPinFeedback {
                        Text(shell.isPinned ? "Pin on" : "Pin off")
                            .font(ShelfStyle.caption).fixedSize()
                            .transition(.opacity)
                    }
                }
                .frame(width: size, height: size)
                .animation(reduceMotion ? nil : ShelfStyle.feedback, value: showingPinFeedback)
            }
            .buttonStyle(RailButtonStyle(resting: shell.isPinned ? ShelfStyle.keycap : .clear))
            .accessibilityLabel(shell.isPinned ? "Unpin panel" : "Pin panel")
            .accessibilityValue(shell.isPinned ? "Pinned" : "Unpinned")
            .help(shell.isPinned
                  ? "Pinned: stays open when you click elsewhere. Click to unpin."
                  : "Unpinned: tucks away when you click elsewhere. Click to pin.")
            .task(id: shell.isPinned) {
                do { try await Task.sleep(for: .seconds(1.3)) } catch { return }
                showingPinFeedback = false
            }
            Menu {
                Picker("Appearance", selection: Binding(get: { shell.preferences.appearance }, set: shell.setAppearance)) {
                    ForEach(PanelAppearance.allCases) { appearance in Text(appearance.title).tag(appearance) }
                }
                Toggle("Full height", isOn: Binding(get: { shell.preferences.fullHeight }, set: shell.setFullHeight))
                Picker("Screen edge", selection: Binding(get: { shell.preferences.edge }, set: shell.setEdge)) {
                    ForEach(ScreenEdge.allCases) { edge in Text(edge.title).tag(edge) }
                }
                Button("Reset panel size", action: shell.resetPanelSize)
                Divider()
                Button("Quit Nivlet") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape").font(.system(size: 14, weight: .medium))
                    .frame(width: size, height: size).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: size, height: size)
            .modifier(RailHover())
            .accessibilityLabel("Panel settings").help("Panel settings")
        }
        .foregroundStyle(ShelfStyle.secondary)
        .padding(8)
        .frame(width: compact ? 48 : 52)
        .panelSurface()
    }

    private func railButton(_ title: String, symbol: String, size: CGFloat, resting: Color = .clear, help: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium)).frame(width: size, height: size)
        }
        .buttonStyle(RailButtonStyle(resting: resting))
        .help(help ?? title).accessibilityLabel(title)
    }

    // MARK: Toast

    @ViewBuilder private var feedback: some View {
        if let message = model.feedback {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: model.isFeedbackError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(model.isFeedbackError ? Color.orange : ShelfStyle.success)
                    .accessibilityHidden(true)
                Text(message).font(.system(size: 12.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                if model.isFeedbackError {
                    Button { model.dismissFeedback() } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                        .buttonStyle(.borderless).accessibilityLabel("Dismiss message").shelfPointer()
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 8)
            // Solid surface: a live blur view doesn't follow the scale transition and pops.
            .background(ShelfStyle.toast, in: RoundedRectangle(cornerRadius: model.isFeedbackError ? 12 : 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: model.isFeedbackError ? 12 : 17, style: .continuous)
                .strokeBorder(ShelfStyle.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .padding(.horizontal, 12)
            .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: 6)))
            .accessibilityHidden(!model.isFeedbackError)
        }
    }
}

/// The ⌘K list of actions for the selected item, in the style of a launcher action panel.
private struct ActionsPanel: View {
    let model: PanelModel
    let commands: [ShelfCommand]
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("ACTIONS").font(ShelfStyle.eyebrow).tracking(0.7).foregroundStyle(ShelfStyle.secondary)
                Spacer()
                Keycap("esc")
            }
            .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 5)
            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                if command.destructive {
                    Rectangle().fill(ShelfStyle.hairline).frame(height: 1).padding(.vertical, 4)
                }
                Button {
                    model.actionsOpen = false
                    command.perform()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: command.symbol).font(.system(size: 12, weight: .medium)).frame(width: 16)
                        Text(command.title).lineLimit(1)
                        Spacer(minLength: 12)
                        if !command.keys.isEmpty { Keycap(keys: command.keys) }
                    }
                    .foregroundStyle(command.destructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(ShelfStyle.ink))
                    .opacity(command.enabled ? 1 : 0.45)
                    .padding(.horizontal, 8).frame(height: 30)
                    .background(index == model.actionIndex && command.enabled ? ShelfStyle.keycap : .clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!command.enabled)
                .onHover { if $0 { model.actionIndex = index } }
                .shelfPointer(command.enabled ? .pointingHand : .arrow)
            }
        }
        .padding(6)
        .frame(maxWidth: 264)
        .panelSurface(radius: 13)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Actions")
    }
}

/// Rail control: neutral at rest, lifted on hover, pressed at 0.96.
private struct RailButtonStyle: ButtonStyle {
    var selected = false
    var resting: Color = .clear
    func makeBody(configuration: Configuration) -> some View { RailButtonBody(configuration: configuration, selected: selected, resting: resting) }
}

private struct RailButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let resting: Color
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        configuration.label
            .foregroundStyle(hovered && !selected ? ShelfStyle.ink : ShelfStyle.secondary)
            .opacity(enabled ? 1 : 0.4)
            .background(selected ? .clear : hovered ? ShelfStyle.keycap : resting, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: configuration.isPressed)
            .onHover { hovered = enabled && $0 }
            .shelfPointer(enabled ? .pointingHand : .arrow)
    }
}

/// Hover lift and pointer for native `Menu` labels, which ignore button styles.
private struct RailHover: ViewModifier {
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .foregroundStyle(hovered ? ShelfStyle.ink : ShelfStyle.secondary)
            .background(hovered ? ShelfStyle.keycap : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
            .shelfPointer()
    }
}
