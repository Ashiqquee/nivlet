import SwiftUI

struct NotesView: View {
    @Bindable var kit: PocketLibrary
    let newTaskRequest: Int
    // Row IDs survive checkbox changes/appends. Whole-text editing rebuilds
    // this projection; the pocket's plain text remains authoritative.
    @State private var document: ScratchpadDocument
    @State private var editingText = false
    @State private var newTask = ""
    @State private var editorFocusRequest = 0
    @FocusState private var addingTask: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kit: PocketLibrary, newTaskRequest: Int) {
        self.kit = kit
        self.newTaskRequest = newTaskRequest
        _document = State(initialValue: ScratchpadDocument(kit.note))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if document.taskCount > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(document.completedCount) of \(document.taskCount) done")
                            .font(ShelfStyle.caption.weight(.semibold)).foregroundStyle(ShelfStyle.secondary).monospacedDigit()
                            .contentTransition(.numericText())
                            .accessibilityAddTraits(.isHeader)
                        Capsule().fill(ShelfStyle.raised).frame(height: 4)
                            .overlay(alignment: .leading) {
                                Capsule().fill(PanelTool.notes.gradient)
                                    .scaleEffect(x: CGFloat(document.completedCount) / CGFloat(document.taskCount), anchor: .leading)
                            }
                            .animation(reduceMotion ? nil : ShelfStyle.settle, value: document.completedCount)
                            .accessibilityHidden(true)
                    }
                } else {
                    Text("Notes & to-dos").font(ShelfStyle.caption.weight(.semibold)).foregroundStyle(ShelfStyle.secondary)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 4)
                Button {
                    editingText.toggle()
                    if editingText { editorFocusRequest += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: editingText ? "checkmark" : "pencil")
                        Text(editingText ? "Done" : "Edit text")
                    }
                }
                .buttonStyle(ShelfButtonStyle(filled: true, compact: true))
                .keyboardShortcut("e", modifiers: .command)
                .help(editingText ? "Done (⌘E)" : "Edit text (⌘E)")
            }
            .padding(.horizontal, 4)

            Group {
                if editingText {
                    PlainTextEditor(text: $kit.note, label: "Scratchpad text", lineSpacing: 6, focusRequest: editorFocusRequest,
                                    onFocusChange: { focused in if !focused { kit.flushSoon() } })
                        .padding(8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            if document.lines.isEmpty {
                                Button { editingText = true; editorFocusRequest += 1 } label: {
                                    Label("Write a note…", systemImage: "square.and.pencil")
                                }
                                .buttonStyle(ShelfButtonStyle(compact: true))
                                .foregroundStyle(ShelfStyle.secondary)
                            }
                            ForEach(document.lines) { line in
                                ScratchpadLineView(line: line) { completed in
                                    document.setCompleted(completed, id: line.id)
                                    kit.note = document.text
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .shelfWell(radius: 12)

            HStack(spacing: 9) {
                Image(systemName: "plus.circle.fill").font(.system(size: 15))
                    .foregroundStyle(PanelTool.notes.tint).accessibilityHidden(true)
                TextField("Add a to-do", text: $newTask)
                    .textFieldStyle(.plain).focused($addingTask)
                    .accessibilityLabel("New to-do")
                    .onSubmit(addTask)
                if !newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Keycap("↵")
                }
                Button("Add", action: addTask)
                    .buttonStyle(ShelfButtonStyle(filled: true, compact: true))
                    .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add to-do")
            }
            .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
            .shelfWell(radius: 11, focused: addingTask)
        }
        .padding(.horizontal, 14).padding(.bottom, 14)
        .onChange(of: kit.note) {
            if document.text != kit.note { document = ScratchpadDocument(kit.note) }
        }
        .onChange(of: newTaskRequest) { editingText = false; addingTask = true }
    }

    private func addTask() {
        if document.text != kit.note { document = ScratchpadDocument(kit.note) }
        guard document.appendTask(newTask) else { return }
        kit.note = document.text
        newTask = ""
        editingText = false
        addingTask = true
    }
}

private struct ScratchpadLineView: View {
    let line: ScratchpadDocument.Line
    let setCompleted: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let completed = line.isCompleted {
            Toggle(isOn: Binding(get: { completed }, set: { value in setCompleted(value) })) {
                Text(line.label.isEmpty ? "Untitled to-do" : line.label)
                    .strikethrough(completed, color: ShelfStyle.tertiary)
                    .foregroundStyle(completed ? ShelfStyle.secondary : ShelfStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(RoundCheckStyle(tint: PanelTool.notes.tint))
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : ShelfStyle.pop, value: completed)
        } else if line.content.isEmpty {
            Color.clear.frame(height: 8).accessibilityHidden(true)
        } else {
            Text(line.content).lineSpacing(4).textSelection(.enabled)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A round, Things-style checkbox. Keeps native toggle semantics for VoiceOver and Space.
private struct RoundCheckStyle: ToggleStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        RoundCheckBody(configuration: configuration, tint: tint)
    }
}

private struct RoundCheckBody: View {
    let configuration: ToggleStyleConfiguration
    let tint: Color
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ZStack {
                    Circle().strokeBorder(configuration.isOn ? .clear : (hovered ? tint : ShelfStyle.tertiary), lineWidth: 1.5)
                    if configuration.isOn {
                        Circle().fill(tint)
                        Image(systemName: "checkmark").font(.system(size: 8.5, weight: .heavy)).foregroundStyle(.white)
                            .transition(.scale(scale: 0.25).combined(with: .opacity))
                    }
                }
                .frame(width: 17, height: 17)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5).padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovered ? ShelfStyle.hover : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
        .shelfPointer()
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
