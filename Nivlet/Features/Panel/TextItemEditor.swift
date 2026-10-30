import SwiftUI

struct TextItemEditor: View {
    let kit: PocketLibrary
    let model: PanelModel
    @Bindable var draft: TextDraft
    @State private var titleFocused = false
    @State private var titleFocusRequest = 1
    @State private var saving = false
    @State private var confirmReset = false
    @State private var bodyFocused = false
    @State private var validationMessage: String?
    @State private var bodyFocusRequest = 0
    @State private var validationTarget: Field?
    @Environment(\.panelTextScale) private var textScale
    private enum Field { case title, text }

    private var parseError: String? {
        guard draft.usesFields, !draft.text.isEmpty else { return nil }
        do { _ = try PromptTemplate.parse(draft.text); return nil } catch { return String(describing: error) }
    }

    private var diagnosticRange: NSRange? {
        guard draft.usesFields else { return nil }
        do { _ = try PromptTemplate.parse(draft.text); return nil }
        catch PromptTemplate.ParseError.malformedToken(let position) {
            let index = draft.text.index(draft.text.startIndex, offsetBy: min(position - 1, draft.text.count))
            guard index < draft.text.endIndex else { return nil }
            return NSRange(index..<draft.text.index(after: index), in: draft.text)
        } catch { return nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { _ = model.closeChild() } label: { Label("Back", systemImage: "chevron.backward") }
                    .buttonStyle(ShelfButtonStyle(compact: true))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.bottom, 8)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ItemGlyph(tool: draft.tool, symbol: draft.usesFields ? "curlybraces" : "text.bubble.fill", size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.id == nil ? "New \(draft.tool.itemName)" : "Edit \(draft.tool.itemName)")
                                    .shelfFont(.display).accessibilityAddTraits(.isHeader)
                                Text("A prompt, rule or context you reuse. Copy it any time.")
                                    .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Title")
                            PlainTextField(text: $draft.title, label: "Title", placeholder: "Give it a name",
                                           focusRequest: titleFocusRequest, onFocusChange: { titleFocused = $0 },
                                           fontSize: 13.5, fontWeight: .medium)
                                .padding(.horizontal, 11).padding(.vertical, 9)
                                .shelfWell(radius: 10, focused: titleFocused)
                                .accessibilityLabel("Title")
                                .accessibilityHint(validationTarget == .title ? (validationMessage ?? "") : "")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Prompt")
                            PlainTextEditor(text: $draft.text, label: "Prompt text", focusRequest: bodyFocusRequest, onFocusChange: { bodyFocused = $0 }, diagnosticRange: diagnosticRange)
                                .padding(7)
                                .frame(height: max(150, geometry.size.height - 280))
                                .shelfWell(radius: 10, focused: bodyFocused)
                                .overlay(alignment: .topLeading) {
                                    if draft.text.isEmpty {
                                        Text("Write or paste your \(draft.tool.itemName)…")
                                            .foregroundStyle(ShelfStyle.tertiary).padding(.horizontal, 13).padding(.vertical, 13).allowsHitTesting(false)
                                    }
                                }
                                .accessibilityLabel("Prompt text")
                                .accessibilityHint(validationTarget == .text ? (validationMessage ?? "") : "")
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            optionRow("Favourite", detail: "Pin it to the top of the shelf.", symbol: "star.fill", tint: ShelfStyle.favourite, isOn: $draft.isFavorite)
                            Rectangle().fill(ShelfStyle.hairline).frame(height: 1).padding(.leading, 38)
                            optionRow("Use named blanks", detail: draft.usesFields
                                      ? "Write {{topic}} where a value should go. Repeated names share one input. Escape literal braces with a backslash."
                                      : "Turn on to fill in {{blanks}} before copying.",
                                      symbol: "curlybraces", tint: PanelTool.prompts.tint, isOn: $draft.usesFields)
                        }
                        .shelfWell(radius: 12)
                        if validationMessage == nil, let message = parseError {
                            validationLabel(message)
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 18)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if let message = validationMessage {
                    validationLabel(message)
                }
                HStack(spacing: 8) {
                    Button { _ = model.closeChild() } label: { HStack(spacing: 7) { Text("Cancel").fixedSize(); if textScale == 1 { Keycap("esc") } } }
                        .buttonStyle(ShelfButtonStyle())
                    Spacer(minLength: 8)
                    Button { saveRequested() } label: {
                        HStack(spacing: 8) {
                            Text(saving ? "Saving…" : "Save").lineLimit(1).fixedSize()
                            if textScale == 1 { Keycap("⌘", "S", inverted: true) }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(saving)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(ShelfStyle.hairline).frame(height: 1) }
        }
        .disabled(saving)
        .onChange(of: draft.title) { draft.hasChanges = true; validationMessage = nil }
        .onChange(of: draft.text) { draft.hasChanges = true; validationMessage = nil }
        .onChange(of: draft.isFavorite) { draft.hasChanges = true }
        .onChange(of: draft.usesFields) { draft.hasChanges = true }
        .alert("Reset filled values?", isPresented: $confirmReset) {
            Button("Save and reset fields") { save() }
            Button("Keep editing", role: .cancel) {}
        } message: { Text("Saving changes to this template clears its filled values. The saved prompt will use the new text.") }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).shelfFont(.caption, weight: .semibold).foregroundStyle(ShelfStyle.secondary)
    }

    private func optionRow(_ title: String, detail: String, symbol: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).shelfFont(size: 11, weight: .semibold).foregroundStyle(tint)
                    .frame(width: 18, height: 18).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).shelfFont(.body, weight: .medium)
                    Text(detail).shelfFont(.caption).foregroundStyle(ShelfStyle.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .toggleStyle(.switch).controlSize(.small)
        .padding(.horizontal, 10).padding(.vertical, 10)
    }

    private func validationLabel(_ message: String) -> some View {
        Label {
            Text(message).foregroundStyle(ShelfStyle.ink)
        } icon: {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
        }
        .shelfFont(.body).fixedSize(horizontal: false, vertical: true)
    }

    private func saveRequested() {
        if !PromptTemplate.isFilled(draft.title) {
            validationMessage = "Add a title so you can find this later."
            validationTarget = .title
            model.announceValidation(validationMessage!)
            titleFocusRequest += 1
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
        if let id = draft.id,
           (kit.prompts.first(where: { $0.id == id })?.source != draft.text || kit.prompts.first(where: { $0.id == id })?.usesFields != draft.usesFields),
           model.fieldValues[id]?.values.contains(where: PromptTemplate.isFilled) == true {
            confirmReset = true
        } else { save() }
    }

    private func save() {
        saving = true
        Task {
            let original = draft.id.flatMap { id in kit.prompts.first(where: { $0.id == id }) }
            let changedSource = original?.source != draft.text || original?.usesFields != draft.usesFields
            let saved = await kit.savePrompt(id: draft.saveID, label: draft.title, source: draft.text, favorite: draft.isFavorite, usesFields: draft.usesFields)
            if changedSource, let id = draft.id { model.fieldValues[id] = nil }
            saving = false
            if model.draft === draft {
                // Save has submitted these values to the library. On failure they
                // remain pending there with Retry; closing this editor must not
                // offer a misleading "Discard" for that submitted save attempt.
                draft.hasChanges = false
                if saved { model.discardDraft() }
            }
        }
    }
}
