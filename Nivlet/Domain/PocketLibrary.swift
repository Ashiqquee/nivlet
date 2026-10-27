import Foundation
import Observation

@Observable
final class PocketLibrary {
    private(set) var pocketID = UUID()
    private(set) var pocketName = "My pocket"
    private(set) var instructions: [Instruction] = []
    private(set) var prompts: [SavedPrompt] = []
    private(set) var references: [ReferenceItem] = []
    var note = "" { didSet { if isLoaded, note != oldValue { changed(debounce: true) } } }
    private(set) var isLoaded = false
    private(set) var isImporting = false
    private(set) var saveState: SaveState = .loading
    let isPreview: Bool

    enum SaveState: Equatable {
        case loading, saving, saved, preview
        case failed(String)
    }

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var savedRevision: UInt64 = 0
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var deletedSnapshot: LibrarySnapshot?

    var hasUnsavedChanges: Bool { isLoaded && !isPreview && revision > savedRevision }
    var canUndoDelete: Bool { deletedSnapshot != nil }

    init(root: URL? = nil, preview: Bool = false, store: LibraryStore? = nil) {
        let root = root ?? URL.applicationSupportDirectory.appending(path: "ashique.nivlet.Nivlet", directoryHint: .isDirectory)
        self.store = store ?? LibraryStore(root: root)
        isPreview = preview
        if preview {
            let samples = SampleKit()
            pocketName = "Design project"
            instructions = samples.instructions
            prompts = [
                SavedPrompt(label: "My writing assistant", source: "Keep the meaning and my voice. Make the writing clearer, remove repetition, and show the revised text first.", isFavorite: true),
                SavedPrompt(label: "Explain a concept", source: "Explain {{topic}} to {{audience}}. Start with an everyday example, then build up the details.", usesFields: true),
                SavedPrompt(label: "Find the tradeoffs", source: "Compare the options I share. Tell me what each makes easier, what it makes harder, and what information is still missing.")
            ]
            references = samples.references
            note = samples.note
            isLoaded = true
            saveState = .preview
        }
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true; saveState = .loading
        defer { isLoading = false }
        do {
            let value = try await store.load()
            apply(value)
            isLoaded = true; saveState = .saved
        } catch { saveState = .failed(error.localizedDescription) }
    }

    @discardableResult
    func saveInstruction(id: UUID?, label: String, body: String, favorite: Bool) async -> Bool {
        guard isLoaded, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, PromptTemplate.isFilled(body) else { return false }
        let item = Instruction(id: id ?? UUID(), label: label, body: body, isFavorite: favorite)
        if let index = instructions.firstIndex(where: { $0.id == item.id }) { instructions[index] = item }
        else { instructions.append(item) }
        changed()
        return await flush()
    }

    @discardableResult
    func savePrompt(id: UUID?, label: String, source: String, favorite: Bool, usesFields: Bool = false) async -> Bool {
        guard isLoaded, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              PromptTemplate.isFilled(source), (!usesFields || (try? PromptTemplate.parse(source)) != nil) else { return false }
        let item = SavedPrompt(id: id ?? UUID(), label: label, source: source, isFavorite: favorite, usesFields: usesFields)
        if let index = prompts.firstIndex(where: { $0.id == item.id }) { prompts[index] = item }
        else { prompts.append(item) }
        changed()
        return await flush()
    }

    func toggleFavorite(id: UUID, tool: PanelTool) {
        if tool == .instructions, let i = instructions.firstIndex(where: { $0.id == id }) { instructions[i].isFavorite.toggle() }
        if tool == .prompts, let i = prompts.firstIndex(where: { $0.id == id }) { prompts[i].isFavorite.toggle() }
        changed(debounce: true)
    }

    func duplicate(id: UUID, tool: PanelTool) {
        if tool == .instructions, let original = instructions.first(where: { $0.id == id }) {
            instructions.append(Instruction(id: UUID(), label: original.label + " copy", body: original.body, isFavorite: false))
        }
        if tool == .prompts, let original = prompts.first(where: { $0.id == id }) {
            prompts.append(SavedPrompt(label: original.label + " copy", source: original.source, usesFields: original.usesFields))
        }
        changed(debounce: true)
    }

    func delete(id: UUID, tool: PanelTool) {
        deletedSnapshot = snapshot
        switch tool {
        case .instructions: instructions.removeAll { $0.id == id }
        case .prompts: prompts.removeAll { $0.id == id }
        case .references: references.removeAll { $0.id == id }
        case .notes: return
        }
        changed(debounce: true)
    }

    func undoDelete() {
        guard let previous = deletedSnapshot else { return }
        // Restore deleted records without rolling back notes or unrelated edits.
        for (position, item) in previous.instructions.enumerated() where !instructions.contains(where: { $0.id == item.id }) { instructions.insert(item, at: min(position, instructions.count)) }
        for (position, item) in previous.prompts.enumerated() where !prompts.contains(where: { $0.id == item.id }) { prompts.insert(item, at: min(position, prompts.count)) }
        for (position, item) in previous.references.enumerated() where !references.contains(where: { $0.id == item.id }) { references.insert(item, at: min(position, references.count)) }
        deletedSnapshot = nil
        changed(debounce: true)
    }

    func renamePocket(_ name: String) {
        guard PromptTemplate.isFilled(name) else { return }
        pocketName = name
        changed(debounce: true)
    }

    func updateReference(id: UUID, note: String) {
        guard let index = references.firstIndex(where: { $0.id == id }) else { return }
        references[index].note = note
        changed(debounce: true)
    }

    func importFiles(_ urls: [URL]) async -> [String] {
        guard isLoaded, !isPreview, !isImporting else { return [] }
        isImporting = true
        defer { isImporting = false }
        var failures: [String] = []
        for url in urls {
            do {
                let item = try await store.importFile(url)
                references.append(item)
                changed()
                if !(await flush()) { failures.append("\(url.lastPathComponent): Couldn't save. Use Retry below.") }
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        return failures
    }

    @discardableResult
    func flush() async -> Bool {
        pendingSave?.cancel(); pendingSave = nil
        guard isLoaded else { return false }
        if isPreview { saveState = .preview; return true }
        let currentRevision = revision
        let current = snapshot
        saveState = .saving
        do {
            let committed = try await store.save(current, revision: currentRevision)
            if committed { savedRevision = max(savedRevision, currentRevision) }
            if currentRevision == revision { saveState = .saved }
            return committed
        } catch {
            if currentRevision == revision { saveState = .failed(error.localizedDescription) }
            return false
        }
    }

    func flushSoon() { Task { await flush() } }

    private func changed(debounce: Bool = false) {
        revision += 1
        guard !isPreview else { return }
        saveState = .saving
        pendingSave?.cancel()
        if debounce {
            pendingSave = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.pendingSave = nil
                await self.flush()
            }
        }
    }

    private var snapshot: LibrarySnapshot {
        LibrarySnapshot(pocketID: pocketID, pocketName: pocketName, instructions: instructions,
                        prompts: prompts, references: references, note: note)
    }

    private func apply(_ value: LibrarySnapshot) {
        pocketID = value.pocketID; pocketName = value.pocketName
        instructions = value.instructions; prompts = value.prompts
        references = value.references; note = value.note
    }
}
