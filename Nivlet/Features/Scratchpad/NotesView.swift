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

    init(kit: PocketLibrary, newTaskRequest: Int) {
        self.kit = kit
        self.newTaskRequest = newTaskRequest
        _document = State(initialValue: ScratchpadDocument(kit.note))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(document.taskCount == 0 ? "Notes & to-dos" : "\(document.completedCount) of \(document.taskCount) completed")
                    .foregroundStyle(ShelfStyle.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button(editingText ? "Done" : "Edit text") {
                    editingText.toggle()
                    if editingText { editorFocusRequest += 1 }
                }
                .buttonStyle(ShelfButtonStyle(compact: true))
                .keyboardShortcut("e", modifiers: .command)
            }
            .padding(.horizontal, 4)

            Group {
                if editingText {
                    PlainTextEditor(text: $kit.note, label: "Scratchpad text", lineSpacing: 6, focusRequest: editorFocusRequest)
                        .padding(8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if document.lines.isEmpty {
                                Button("Write a note…") { editingText = true; editorFocusRequest += 1 }
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
                        .padding(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Image(systemName: "plus").foregroundStyle(ShelfStyle.secondary).accessibilityHidden(true)
                TextField("Add a to-do", text: $newTask)
                    .textFieldStyle(.plain).focused($addingTask)
                    .accessibilityLabel("New to-do")
                    .onSubmit(addTask)
                Button("Add", action: addTask)
                    .buttonStyle(ShelfButtonStyle(compact: true))
                    .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add to-do")
            }
            .padding(8)
            .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(addingTask ? ShelfStyle.focusRing : .clear, lineWidth: 2))
        }
        .padding(.horizontal, 12).padding(.bottom, 5)
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
                    .strikethrough(completed)
                    .foregroundStyle(completed ? ShelfStyle.secondary : ShelfStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: completed)
        } else if line.content.isEmpty {
            Color.clear.frame(height: 8).accessibilityHidden(true)
        } else {
            Text(line.content).lineSpacing(4).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
