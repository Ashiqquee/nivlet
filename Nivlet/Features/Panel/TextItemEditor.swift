import SwiftUI

struct TextItemEditor: View {
    let kit: PocketLibrary
    let model: PanelModel
    @Bindable var draft: TextDraft
    @FocusState private var focusedField: Field?
    @State private var saving = false
    @State private var confirmReset = false
    @State private var bodyFocused = false
    @State private var validationMessage: String?
    @State private var bodyFocusRequest = 0
    @State private var validationTarget: Field?
    private enum Field { case title, text }

    private var parseError: String? {
        guard draft.tool == .prompts, draft.usesFields, !draft.text.isEmpty else { return nil }
        do { _ = try PromptTemplate.parse(draft.text); return nil } catch { return String(describing: error) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label("Back", systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true))
                Spacer()
                Text(draft.id == nil ? "New \(draft.tool.itemName)" : "Edit \(draft.tool.itemName)")
                    .font(ShelfStyle.body.weight(.medium)).foregroundStyle(ShelfStyle.secondary)
            }
            .padding(.horizontal, 12).padding(.bottom, 8)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Title").font(ShelfStyle.body.weight(.medium))
                            TextField("Give it a name", text: $draft.title)
                                .textFieldStyle(.plain).padding(10)
                                .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 10))
                                .focused($focusedField, equals: .title)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focusedField == .title ? ShelfStyle.focusRing : ShelfStyle.border.opacity(0.4), lineWidth: focusedField == .title ? 2 : 1))
                                .accessibilityLabel("Title")
                                .accessibilityHint(validationTarget == .title ? (validationMessage ?? "") : "")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(draft.tool == .prompts ? "Prompt" : "Instruction").font(ShelfStyle.body.weight(.medium))
                            PlainTextEditor(text: $draft.text, label: draft.tool == .prompts ? "Prompt text" : "Instruction text", focusRequest: bodyFocusRequest, onFocusChange: { bodyFocused = $0 })
                                .padding(8)
                                .frame(height: max(150, geometry.size.height - 200))
                                .background(ShelfStyle.card, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(bodyFocused ? ShelfStyle.focusRing : ShelfStyle.border.opacity(0.4), lineWidth: bodyFocused ? 2 : 1))
                                .overlay(alignment: .topLeading) {
                                    if draft.text.isEmpty {
                                        Text("Write or paste your \(draft.tool.itemName)…")
                                            .foregroundStyle(ShelfStyle.secondary).padding(13).allowsHitTesting(false)
                                    }
                                }
                                .accessibilityLabel(draft.tool == .prompts ? "Prompt text" : "Instruction text")
                                .accessibilityHint(validationTarget == .text ? (validationMessage ?? "") : "")
                        }
                        Toggle("Favourite", isOn: $draft.isFavorite).toggleStyle(.checkbox)
                        if draft.tool == .prompts {
                            Toggle("Use named blanks", isOn: $draft.usesFields).toggleStyle(.checkbox)
                            if draft.usesFields {
                                Text("Optional: write {{topic}} where a value should go. Repeated names share one input. Escape literal braces with a backslash.")
                                    .font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary).padding(.top, 5)
                            }
                        }
                        if validationMessage == nil, let message = parseError {
                            validationLabel(message)
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 14)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let message = validationMessage {
                    validationLabel(message)
                }
            HStack {
                Button("Cancel") { _ = model.closeChild() }.buttonStyle(ShelfButtonStyle())
                Spacer(minLength: 8)
                Button(saving ? "Saving…" : "Save \(draft.tool.itemName)") { saveRequested() }
                    .buttonStyle(.borderedProminent).controlSize(.regular).disabled(saving)
                    .keyboardShortcut("s", modifiers: .command)
            }

            }
            .padding(12)
        }
        .defaultFocus($focusedField, .title)
        .onChange(of: draft.title) { draft.hasChanges = true; validationMessage = nil }
        .onChange(of: draft.text) { draft.hasChanges = true; validationMessage = nil }
        .onChange(of: draft.isFavorite) { draft.hasChanges = true }
        .onChange(of: draft.usesFields) { draft.hasChanges = true }
        .alert("Reset filled values?", isPresented: $confirmReset) {
            Button("Save and reset fields") { save() }
            Button("Keep editing", role: .cancel) {}
        } message: { Text("Saving changes to this template clears its filled values. The saved prompt will use the new text.") }
    }

    private func validationLabel(_ message: String) -> some View {
        Label {
            Text(message).foregroundStyle(ShelfStyle.ink)
        } icon: {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
        }
        .font(ShelfStyle.body).fixedSize(horizontal: false, vertical: true)
    }

    private func saveRequested() {
        if !PromptTemplate.isFilled(draft.title) {
            validationMessage = "Add a title so you can find this later."
            validationTarget = .title
            model.announceValidation(validationMessage!)
            focusedField = .title
            return
        }
        if !PromptTemplate.isFilled(draft.text) {
            validationMessage = "Add your \(draft.tool.itemName) text before saving."
            validationTarget = .text
            model.announceValidation(validationMessage!)
            bodyFocusRequest += 1
            return
        }
        if let parseError {
            validationMessage = parseError
            validationTarget = .text
            model.announceValidation(parseError)
            bodyFocusRequest += 1
            return
        }
        validationMessage = nil
        if let id = draft.id, draft.tool == .prompts,
           (kit.prompts.first(where: { $0.id == id })?.source != draft.text || kit.prompts.first(where: { $0.id == id })?.usesFields != draft.usesFields),
           model.fieldValues[id]?.values.contains(where: PromptTemplate.isFilled) == true {
            confirmReset = true
        } else { save() }
    }

    private func save() {
        saving = true
        Task {
            let saved: Bool
            if draft.tool == .prompts {
                let original = draft.id.flatMap { id in kit.prompts.first(where: { $0.id == id }) }
                let changedSource = original?.source != draft.text || original?.usesFields != draft.usesFields
                saved = await kit.savePrompt(id: draft.saveID, label: draft.title, source: draft.text, favorite: draft.isFavorite, usesFields: draft.usesFields)
                if saved, changedSource, let id = draft.id { model.fieldValues[id] = nil }
            } else {
                saved = await kit.saveInstruction(id: draft.saveID, label: draft.title, body: draft.text, favorite: draft.isFavorite)
            }
            saving = false
            if saved { model.discardDraft() }
        }
    }
}
