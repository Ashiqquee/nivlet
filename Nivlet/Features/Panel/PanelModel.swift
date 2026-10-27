import AppKit
import Observation

nonisolated enum PanelTool: String, CaseIterable, Identifiable, Sendable {
    case instructions, prompts, references, notes
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .instructions: "text.quote"
        case .prompts: "curlybraces"
        case .references: "photo.on.rectangle.angled"
        case .notes: "note.text"
        }
    }
    var shortcut: Character {
        switch self { case .instructions: "1"; case .prompts: "2"; case .references: "3"; case .notes: "4" }
    }
    var title: String {
        switch self { case .instructions: "Instructions"; case .prompts: "Prompts"; case .references: "References"; case .notes: "Scratchpad" }
    }
    var itemName: String { self == .instructions ? "instruction" : "prompt" }
}

nonisolated enum PanelInspector: Equatable {
    case instruction(UUID), prompt(UUID), reference(UUID), editor
}

@Observable
final class TextDraft {
    let id: UUID?
    let saveID: UUID
    let tool: PanelTool
    var title: String
    var text: String
    var isFavorite: Bool
    var hasChanges = false
    var usesFields: Bool

    init(id: UUID? = nil, tool: PanelTool, title: String = "", text: String = "", isFavorite: Bool = false, usesFields: Bool = false) {
        self.id = id; self.saveID = id ?? UUID(); self.tool = tool; self.title = title; self.text = text; self.isFavorite = isFavorite; self.usesFields = usesFields
    }
}

@Observable
final class PanelModel {
    var tool: PanelTool = .prompts
    var inspector: PanelInspector?
    var draft: TextDraft?
    var query = ""
    var searchFocusRequest = 0
    var showDiscardConfirmation = false
    var fieldValues: [UUID: [String: String]] = [:]
    var isFeedbackError = false
    private(set) var feedback: String?
    @ObservationIgnored var focusForEditing: () -> Void = {}
    var newScratchpadTaskRequest = 0
    @ObservationIgnored private var pendingTool: PanelTool?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    func select(_ tool: PanelTool) {
        guard !(draft?.hasChanges ?? false) else { pendingTool = tool; showDiscardConfirmation = true; return }
        self.tool = tool; inspector = nil; draft = nil; query = ""
    }

    func beginNew() {
        guard tool == .prompts || tool == .instructions else { return }
        guard !(draft?.hasChanges ?? false) else { showDiscardConfirmation = true; return }
        draft = TextDraft(tool: tool)
        inspector = .editor
        focusForEditing()
    }

    func beginScratchpadTask() {
        focusForEditing()
        newScratchpadTaskRequest += 1
    }

    func edit(_ instruction: Instruction) {
        draft = TextDraft(id: instruction.id, tool: .instructions, title: instruction.label,
                          text: instruction.body, isFavorite: instruction.isFavorite)
        inspector = .editor; focusForEditing()
    }

    func edit(_ prompt: SavedPrompt) {
        draft = TextDraft(id: prompt.id, tool: .prompts, title: prompt.label,
                          text: prompt.source, isFavorite: prompt.isFavorite, usesFields: prompt.usesFields)
        inspector = .editor; focusForEditing()
    }

    func closeChild() -> Bool {
        guard inspector != nil else { return false }
        if draft?.hasChanges == true { pendingTool = nil; showDiscardConfirmation = true; return true }
        inspector = nil; draft = nil
        return true
    }

    func discardDraft() {
        draft = nil; inspector = nil
        if let destination = pendingTool { tool = destination; query = "" }
        pendingTool = nil
    }

    func cancelPendingNavigation() { pendingTool = nil }

    func copy(_ text: String) {
        if TextCopier.copy(text) { showFeedback("Text copied") }
        else { showFeedback("Couldn't copy. Try again.", isError: true) }
    }

    func announceValidation(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func dismissFeedback() { feedbackTask?.cancel(); feedback = nil; isFeedbackError = false }

    func showFeedback(_ message: String, isError: Bool = false) {
        feedbackTask?.cancel()
        feedback = message; isFeedbackError = isError
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        guard !isError else { return }
        feedbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1.8)) } catch { return }
            self?.feedback = nil
        }
    }
}
