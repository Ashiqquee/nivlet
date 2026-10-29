import AppKit
import Observation

nonisolated enum PanelTool: String, CaseIterable, Identifiable, Sendable {
    case prompts, references, notes
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .prompts: "text.bubble.fill"
        case .references: "photo.fill.on.rectangle.fill"
        case .notes: "checklist"
        }
    }
    var shortcut: Character {
        switch self { case .prompts: "1"; case .references: "2"; case .notes: "3" }
    }
    var title: String {
        switch self { case .prompts: "Prompts"; case .references: "References"; case .notes: "Scratchpad" }
    }
    var itemName: String { "prompt" }
}

nonisolated enum PanelInspector: Equatable {
    case prompt(UUID), reference(UUID), editor
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
    @ObservationIgnored let transferPasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) { transferPasteboard = pasteboard }
    var tool: PanelTool = .prompts
    var inspector: PanelInspector?
    var draft: TextDraft?
    var query = "" { didSet { if query != oldValue { selection = nil; actionsOpen = false } } }
    /// Highlighted list item; `nil` falls back to the first visible row.
    var selection: UUID?
    var actionsOpen = false
    var actionIndex = 0
    /// Set by keyboard navigation so the list scrolls the selection into view (hover does not).
    var revealRequest: UUID?
    /// The row that was just copied, for its inline confirmation.
    private(set) var lastCopiedID: UUID?
    var searchFocusRequest = 0
    var showDiscardConfirmation = false
    var fieldValues: [UUID: [String: String]] = [:]
    var preparedReferenceURLs: [UUID: URL] = [:]
    var isFeedbackError = false
    private(set) var feedback: String?
    @ObservationIgnored var focusForEditing: () -> Void = {}
    var newScratchpadTaskRequest = 0
    @ObservationIgnored private var pendingTool: PanelTool?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    func select(_ tool: PanelTool) {
        guard !(draft?.hasChanges ?? false) else { pendingTool = tool; showDiscardConfirmation = true; return }
        self.tool = tool; inspector = nil; draft = nil; query = ""; selection = nil; actionsOpen = false
    }

    func beginNew() {
        guard tool == .prompts else { return }
        guard !(draft?.hasChanges ?? false) else { showDiscardConfirmation = true; return }
        draft = TextDraft(tool: tool)
        inspector = .editor
        focusForEditing()
    }

    func beginScratchpadTask() {
        focusForEditing()
        newScratchpadTaskRequest += 1
    }

    func edit(_ prompt: SavedPrompt) {
        draft = TextDraft(id: prompt.id, tool: .prompts, title: prompt.label,
                          text: prompt.source, isFavorite: prompt.isFavorite, usesFields: prompt.usesFields)
        inspector = .editor; focusForEditing()
    }

    func closeChild() -> Bool {
        if actionsOpen { actionsOpen = false; return true }
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

    func copy(_ text: String, from id: UUID? = nil) {
        if TextCopier.copy(text, to: transferPasteboard) {
            lastCopiedID = id
            showFeedback("Copied to clipboard")
        } else { showFeedback("Couldn't copy. Try again.", isError: true) }
    }

    #if DEBUG
    /// Capture hook: the copy-success state without touching the clipboard.
    func simulateCopiedForCapture(_ id: UUID) {
        lastCopiedID = id
        showFeedback("Copied to clipboard")
    }
    #endif

    func announceValidation(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func dismissFeedback() { feedbackTask?.cancel(); feedback = nil; isFeedbackError = false; lastCopiedID = nil }

    func showFeedback(_ message: String, isError: Bool = false, persists: Bool = false) {
        feedbackTask?.cancel()
        feedback = message; isFeedbackError = isError
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        guard !isError, !persists else { return }
        feedbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1.8)) } catch { return }
            self?.feedback = nil
            self?.lastCopiedID = nil
        }
    }
}
