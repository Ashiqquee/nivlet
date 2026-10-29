import Foundation
import Observation

@Observable
final class PocketLibrary {
    private(set) var pocketID = UUID()
    private(set) var pocketName = "My pocket"
    private(set) var prompts: [SavedPrompt] = []
    private(set) var references: [ReferenceItem] = []
    var note = "" { didSet { if isLoaded, note != oldValue { changed(debounce: true) } } }
    private(set) var isLoaded = false
    private(set) var isImporting = false
    private(set) var importResults: [ReferenceImportResult] = []
    @ObservationIgnored private var retrySources: [UUID: ReferenceImportSource] = [:]
    @ObservationIgnored private var importRevisions: [UUID: UInt64] = [:]
    private(set) var saveState: SaveState = .loading
    private(set) var needsRecoveryReview = false
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
    private enum DeletedRecord {
        case prompt(SavedPrompt, Int)
        case reference(ReferenceItem, Int)
    }
    private var deletedRecords: [DeletedRecord] = []

    var hasUnsavedChanges: Bool { isLoaded && !isPreview && revision > savedRevision }
    var canUndoDelete: Bool { !deletedRecords.isEmpty }

    init(root: URL? = nil, preview: Bool = false, store: LibraryStore? = nil) {
        let root = root ?? URL.applicationSupportDirectory.appending(path: "ashique.nivlet.Nivlet", directoryHint: .isDirectory)
        self.store = store ?? LibraryStore(root: root)
        isPreview = preview
        if preview {
            let samples = SampleKit()
            pocketName = "Design project"
            prompts = [
                SavedPrompt(label: "My writing assistant", source: "Keep the meaning and my voice. Make the writing clearer, remove repetition, and show the revised text first.", isFavorite: true),
                SavedPrompt(label: "Explain a concept", source: "Explain {{topic}} to {{audience}}. Start with an everyday example, then build up the details.", usesFields: true),
                SavedPrompt(label: "Find the tradeoffs", source: "Compare the options I share. Tell me what each makes easier, what it makes harder, and what information is still missing.")
            ] + samples.rules
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
            if let recovered = try await store.recoverableSnapshot() {
                guard recovered.pocketID == pocketID else { throw LibraryStoreError.database("recovery pocket mismatch") }
                apply(recovered)
                revision = 1
                needsRecoveryReview = true
                saveState = .failed("Recovered unsaved changes. Review them, then retry saving.")
            } else { saveState = .saved }
            isLoaded = true
        } catch { saveState = .failed(error.localizedDescription) }
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
        guard isLoaded, tool == .prompts, let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].isFavorite.toggle()
        changed(debounce: true)
    }

    func duplicate(id: UUID, tool: PanelTool) {
        guard isLoaded, tool == .prompts, let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        let original = prompts[index]
        prompts.insert(SavedPrompt(label: original.label + " copy", source: original.source,
                                   isFavorite: original.isFavorite, usesFields: original.usesFields), at: index + 1)
        changed(debounce: true)
    }

    /// Moves within the visible favourite/other group so the shelf's order agrees
    /// with the persisted order, even when the two groups are interleaved in storage.
    func canMovePrompt(id: UUID, by offset: Int) -> Bool {
        guard let item = prompts.first(where: { $0.id == id }), offset == -1 || offset == 1 else { return false }
        let group = prompts.filter { $0.isFavorite == item.isFavorite }
        guard let index = group.firstIndex(where: { $0.id == id }) else { return false }
        return group.indices.contains(index + offset)
    }

    func movePrompt(id: UUID, by offset: Int) {
        guard isLoaded, canMovePrompt(id: id, by: offset), let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        let group = prompts.indices.filter { prompts[$0].isFavorite == prompts[index].isFavorite }
        guard let position = group.firstIndex(of: index) else { return }
        prompts.swapAt(index, group[position + offset])
        changed(debounce: true)
    }

    func delete(id: UUID, tool: PanelTool) {
        guard isLoaded, (tool == .prompts && prompts.contains(where: { $0.id == id })) ||
                (tool == .references && references.contains(where: { $0.id == id })) else { return }
        switch tool {
        case .prompts:
            if let index = prompts.firstIndex(where: { $0.id == id }) {
                deletedRecords.append(.prompt(prompts.remove(at: index), index))
            }
        case .references:
            if let index = references.firstIndex(where: { $0.id == id }) {
                deletedRecords.append(.reference(references.remove(at: index), index))
            }
        case .notes: return
        }
        changed(debounce: true)
    }

    func undoDelete() {
        guard let previous = deletedRecords.popLast() else { return }
        // Restore only this deletion, preserving unrelated edits and earlier Undo steps.
        switch previous {
        case .prompt(let item, let position):
            if !prompts.contains(where: { $0.id == item.id }) { prompts.insert(item, at: min(position, prompts.count)) }
        case .reference(let item, let position):
            if !references.contains(where: { $0.id == item.id }) { references.insert(item, at: min(position, references.count)) }
        }
        changed(debounce: true)
    }

    func renamePocket(_ name: String) {
        guard isLoaded, PromptTemplate.isFilled(name) else { return }
        pocketName = name
        changed(debounce: true)
    }

    func updateReference(id: UUID, note: String) {
        guard let index = references.firstIndex(where: { $0.id == id }) else { return }
        references[index].note = note
        changed(debounce: true)
    }

    func renameReference(id: UUID, label: String) {
        guard PromptTemplate.isFilled(label), let index = references.firstIndex(where: { $0.id == id }) else { return }
        references[index].label = label
        changed(debounce: true)
    }

    var failedImportIDs: [UUID] {
        importResults.compactMap { result in
            if case .failed = result.state { return result.id }
            return nil
        }
    }

    func referenceIsPending(_ id: UUID) -> Bool {
        importResults.contains { $0.referenceID == id && $0.state != .saved }
    }

    func dismissImportResults() {
        guard !isImporting else { return }
        importResults = []; retrySources = [:]; importRevisions = [:]
    }

    @discardableResult
    func importFiles(_ urls: [URL]) async -> [String] {
        await importSources(urls.map(ReferenceImportSource.file))
    }

    @discardableResult
    func importSources(_ sources: [ReferenceImportSource]) async -> [String] {
        guard isLoaded, !isPreview, !isImporting else { return [] }
        let ids = sources.map { source in
            let id = UUID()
            retrySources[id] = source
            importResults.append(.init(id: id, name: source.name))
            return id
        }
        return await processImports(ids)
    }

    @discardableResult
    func retryImports(_ ids: [UUID], confirmed: Bool = false) async -> [String] {
        guard isLoaded, !isPreview, !isImporting else { return [] }
        return await processImports(ids.filter { retrySources[$0] != nil }, confirmed: confirmed)
    }

    func replaceImportSource(id: UUID, with url: URL) async {
        guard !isImporting, let index = importResults.firstIndex(where: { $0.id == id }),
              importResults[index].referenceID == nil else { return }
        retrySources[id] = .file(url)
        importResults[index].name = url.lastPathComponent
        _ = await retryImports([id])
    }

    func originalImportURL(_ id: UUID) -> URL? {
        if case .file(let url) = retrySources[id] { return url }
        return nil
    }

    private func processImports(_ ids: [UUID], confirmed: Bool = false) async -> [String] {
        isImporting = true
        defer { isImporting = false }
        var failures: [String] = []
        for id in ids {
            guard let source = retrySources[id], let index = importResults.firstIndex(where: { $0.id == id }) else { continue }
            importResults[index].state = .importing
            do {
                // A metadata retry uses the already staged item/identity; never
                // reimport successes or manufacture a duplicate after a failed save.
                if let existing = importResults[index].referenceID, references.contains(where: { $0.id == existing }) {
                    if !(await retrySaving()) { throw LibraryStoreError.database("import commit") }
                } else {
                    let item = try await store.importSource(source, confirmed: confirmed)
                    references.append(item)
                    changed()
                    importResults[index].referenceID = item.id
                    importResults[index].warning = ReferenceImportLimits().warns(item.byteCount ?? 0)
                    importRevisions[id] = revision
                    if !(await flush()) { throw LibraryStoreError.database("import commit") }
                }
                importResults[index].state = .saved
                retrySources[id] = nil
            } catch LibraryStoreError.confirmLargeFile {
                importResults[index].state = .needsConfirmation
            } catch {
                let message = error is CancellationError ? "Import cancelled. Retry when ready." : error.localizedDescription
                importResults[index].state = .failed(message)
                failures.append("\(source.name): \(message)")
            }
        }
        return failures
    }

    @discardableResult
    func flush() async -> Bool {
        pendingSave?.cancel(); pendingSave = nil
        guard isLoaded else { return false }
        if isPreview { saveState = .preview; return true }
        // Focus, tuck and tool changes must not silently accept recovered edits.
        guard !needsRecoveryReview else { return false }
        guard hasUnsavedChanges else { return true }
        let currentRevision = revision
        let current = snapshot
        saveState = .saving
        do {
            let committed = try await store.save(current, revision: currentRevision)
            if committed {
                savedRevision = max(savedRevision, currentRevision)
                for index in importResults.indices {
                    let id = importResults[index].id
                    if let importRevision = importRevisions[id], importRevision <= currentRevision {
                        importResults[index].state = .saved
                        importRevisions[id] = nil; retrySources[id] = nil
                    }
                }
            }
            if currentRevision == revision {
                saveState = committed ? .saved : .failed("Couldn't save this revision. Your changes are still here. Retry saving.")
            }
            return committed
        } catch {
            if currentRevision == revision { saveState = .failed(error.localizedDescription) }
            return false
        }
    }

    @discardableResult
    func retrySaving() async -> Bool {
        needsRecoveryReview = false
        return await flush()
    }

    func flushSoon() { Task { await flush() } }

    private func changed(debounce: Bool = false) {
        revision += 1
        guard !isPreview else { return }
        guard !needsRecoveryReview else { return }
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
        LibrarySnapshot(pocketID: pocketID, pocketName: pocketName,
                        prompts: prompts, references: references, note: note)
    }

    private func apply(_ value: LibrarySnapshot) {
        pocketID = value.pocketID; pocketName = value.pocketName
        prompts = value.prompts
        references = value.references; note = value.note
    }
}
