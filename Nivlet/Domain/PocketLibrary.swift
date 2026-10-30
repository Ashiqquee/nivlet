import Foundation
import Observation

@Observable
final class PocketLibrary {
    private(set) var collection = PocketCollection(pocket: .empty)
    private var activeIndex: Int { collection.pockets.firstIndex { $0.pocketID == collection.activePocketID }! }
    var pockets: [LibrarySnapshot] { collection.pockets }
    var pocketID: UUID { collection.activePocketID }
    private(set) var pocketName: String {
        get { collection.pockets[activeIndex].pocketName }
        set { collection.pockets[activeIndex].pocketName = newValue }
    }
    private(set) var prompts: [SavedPrompt] {
        get { collection.pockets[activeIndex].prompts }
        set { collection.pockets[activeIndex].prompts = newValue }
    }
    private(set) var references: [ReferenceItem] {
        get { collection.pockets[activeIndex].references }
        set { collection.pockets[activeIndex].references = newValue }
    }
    var note: String {
        get { collection.pockets[activeIndex].note }
        set {
            guard note != newValue else { return }
            collection.pockets[activeIndex].note = newValue
            if isLoaded { changed(debounce: true) }
        }
    }
    private(set) var isSwitching = false
    private(set) var archivePreview: ArchivePreview?
    private(set) var archiveError: String?
    private(set) var archiveMessage: String?
    private(set) var isArchiveBusy = false
    private(set) var maintenanceNotice: String?
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
    private var deletedRecords: [(owner: UUID, record: DeletedRecord)] = []

    var hasUnsavedChanges: Bool { isLoaded && !isPreview && revision > savedRevision }
    var canUndoDelete: Bool { deletedRecords.contains { $0.owner == pocketID } }

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
            collection = try await store.loadCollection()
            if let recovered = try await store.recoverableCollection() {
                collection = recovered
                revision = 1
                needsRecoveryReview = true
                saveState = .failed("Recovered unsaved changes. Review them, then retry saving.")
            } else { saveState = .saved }
            isLoaded = true
            do { try await store.reconcileInterruptedArchives() }
            catch { maintenanceNotice = "An interrupted file operation needs review. Your library is available; unused-file cleanup is paused." }
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
        guard isLoaded else { return }
        if tool == .prompts, let i = prompts.firstIndex(where: { $0.id == id }) { prompts[i].isFavorite.toggle() }
        else if tool == .references, let i = references.firstIndex(where: { $0.id == id }) { references[i].isFavorite.toggle() }
        else { return }
        changed(debounce: true)
    }

    func duplicate(id: UUID, tool: PanelTool) {
        guard isLoaded else { return }
        if tool == .prompts, let index = prompts.firstIndex(where: { $0.id == id }) {
            let original = prompts[index]
            prompts.insert(SavedPrompt(label: original.label + " copy", source: original.source,
                                       isFavorite: original.isFavorite, usesFields: original.usesFields), at: index + 1)
        } else if tool == .references, let index = references.firstIndex(where: { $0.id == id }) {
            references.insert(copyReference(references[index]), at: index + 1)
        } else { return }
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
                deletedRecords.append((pocketID, .prompt(prompts.remove(at: index), index)))
            }
        case .references:
            if let index = references.firstIndex(where: { $0.id == id }) {
                deletedRecords.append((pocketID, .reference(references.remove(at: index), index)))
            }
        case .notes: return
        }
        changed(debounce: true)
    }

    func undoDelete() {
        guard let index = deletedRecords.lastIndex(where: { $0.owner == pocketID }) else { return }
        let previous = deletedRecords.remove(at: index).record
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
        guard isLoaded, !isPreview, !isImporting, !isSwitching else { return [] }
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
        guard isLoaded, !isPreview, !isImporting, !isSwitching else { return [] }
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
        let current = collection
        saveState = .saving
        do {
            let committed = try await store.saveCollection(current, revision: currentRevision)
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

    var assetReferenceCounts: [URL: Int] {
        var counts = collection.assetReferenceCounts
        for deletion in deletedRecords {
            if case .reference(let item, _) = deletion.record { counts[item.originalURL, default: 0] += 1 }
        }
        return counts
    }

    var currentView: PocketViewBookmark? { collection.pockets[activeIndex].view }

    func updateView(_ view: PocketViewBookmark) {
        guard isLoaded, !isSwitching, currentView != view else { return }
        collection.pockets[activeIndex].view = view
        changed(debounce: true)
    }

    func search(_ query: String, scope: PocketSearchScope) -> [PocketSearchResult] { collection.search(query, scope: scope) }

    @discardableResult
    func createPocket(_ name: String) -> UUID? {
        guard isLoaded, !isSwitching, PromptTemplate.isFilled(name) else { return nil }
        var pocket = LibrarySnapshot.empty; pocket.pocketName = name
        collection.pockets.append(pocket)
        changed(debounce: true)
        return pocket.pocketID
    }

    @discardableResult
    func switchPocket(to id: UUID) async -> Bool {
        guard isLoaded, !isSwitching, !isImporting,
              pockets.contains(where: { $0.pocketID == id }) else { return false }
        if id == pocketID { return true }
        isSwitching = true
        defer { isSwitching = false }
        // A failed/recovered save keeps the current pocket visible for review.
        guard await flush() else { return false }
        collection.activePocketID = id
        dismissImportResults()
        changed()
        _ = await flush()
        return true
    }

    func reorderPocket(id: UUID, by offset: Int) {
        guard !isSwitching, let index = pockets.firstIndex(where: { $0.pocketID == id }),
              abs(offset) == 1, pockets.indices.contains(index + offset) else { return }
        collection.pockets.swapAt(index, index + offset)
        changed(debounce: true)
    }

    func canReorderPocket(id: UUID, by offset: Int) -> Bool {
        guard let index = pockets.firstIndex(where: { $0.pocketID == id }), abs(offset) == 1 else { return false }
        return pockets.indices.contains(index + offset)
    }

    @discardableResult
    func duplicatePocket() -> UUID? {
        guard isLoaded, !isSwitching, !isImporting else { return nil }
        let original = collection.pockets[activeIndex]
        let copy = LibrarySnapshot(pocketID: UUID(), pocketName: original.pocketName + " copy",
            prompts: original.prompts.map { SavedPrompt(label: $0.label, source: $0.source, isFavorite: $0.isFavorite, usesFields: $0.usesFields) },
            references: original.references.map { copyReference($0, suffix: "") }, note: original.note)
        collection.pockets.insert(copy, at: activeIndex + 1)
        changed(debounce: true)
        return copy.pocketID
    }

    /// Caller presents a confirmation before invoking this operation.
    @discardableResult
    func deletePocket(now: Date = Date()) async -> Bool {
        guard isLoaded, !isImporting, !isSwitching else { return false }
        isSwitching = true
        defer { isSwitching = false }
        guard await flush() else { return false }
        let position = activeIndex
        let removed = collection.pockets.remove(at: position)
        collection.trash.append(TrashedPocket(pocket: removed, deletedAt: now))
        if pockets.isEmpty { collection.pockets.append(.empty) }
        collection.activePocketID = pockets[min(position, pockets.count - 1)].pocketID
        dismissImportResults()
        changed()
        _ = await flush()
        return true
    }

    func recoverablePockets(at now: Date = Date()) -> [TrashedPocket] {
        collection.trash.filter { $0.canRestore(at: now) }
    }

    @discardableResult
    func restorePocket(id: UUID, now: Date = Date()) -> Bool {
        guard !isSwitching, let index = collection.trash.firstIndex(where: { $0.id == id }),
              collection.trash[index].canRestore(at: now) else { return false }
        collection.pockets.append(collection.trash.remove(at: index).pocket)
        changed(debounce: true)
        return true
    }

    @discardableResult
    func moveItem(id: UUID, tool: PanelTool, to destination: UUID) -> Bool {
        guard isLoaded, !isImporting, !isSwitching, destination != pocketID,
              let target = pockets.firstIndex(where: { $0.pocketID == destination }) else { return false }
        switch tool {
        case .prompts:
            guard let index = prompts.firstIndex(where: { $0.id == id }) else { return false }
            let item = prompts.remove(at: index)
            collection.pockets[target].prompts.append(item)
        case .references:
            guard let index = references.firstIndex(where: { $0.id == id }) else { return false }
            let item = references.remove(at: index)
            collection.pockets[target].references.append(item)
        case .notes: return false
        }
        changed(debounce: true)
        return true
    }

    func canMoveReference(id: UUID, by offset: Int) -> Bool {
        guard let item = references.first(where: { $0.id == id }), abs(offset) == 1 else { return false }
        let group = references.filter { $0.isFavorite == item.isFavorite }
        guard let index = group.firstIndex(where: { $0.id == id }) else { return false }
        return group.indices.contains(index + offset)
    }

    func moveReference(id: UUID, by offset: Int) {
        guard canMoveReference(id: id, by: offset), let index = references.firstIndex(where: { $0.id == id }) else { return }
        let group = references.indices.filter { references[$0].isFavorite == references[index].isFavorite }
        guard let position = group.firstIndex(of: index) else { return }
        references.swapAt(index, group[position + offset])
        changed(debounce: true)
    }

    private func copyReference(_ item: ReferenceItem, suffix: String = " copy") -> ReferenceItem {
        ReferenceItem(id: UUID(), label: item.label + suffix, note: item.note, displayName: item.displayName,
                      originalURL: item.originalURL, isImage: item.isImage, byteCount: item.byteCount, isFavorite: item.isFavorite)
    }

    func prepareArchiveExport(all: Bool) async {
        guard isLoaded, !isPreview, !isImporting, !isSwitching, !isArchiveBusy else { return }
        isArchiveBusy = true; archiveError = nil; archiveMessage = nil
        defer { isArchiveBusy = false }
        guard await flush() else { archiveError = "Save or recover your current changes before exporting."; return }
        do {
            archivePreview = try await store.prepareExport(all ? pockets : [collection.pockets[activeIndex]])
        } catch { archiveError = archiveFailureMessage(error) }
    }

    func prepareArchiveRestore(from url: URL) async {
        guard isLoaded, !isPreview, !isImporting, !isSwitching, !isArchiveBusy else { return }
        isArchiveBusy = true; archiveError = nil; archiveMessage = nil
        defer { isArchiveBusy = false }
        do { archivePreview = try await store.prepareRestore(from: url) }
        catch { archiveError = archiveFailureMessage(error) }
    }

    @discardableResult
    func writeArchive(to destination: URL) async -> Bool {
        guard let preview = archivePreview, !isArchiveBusy else { return false }
        isArchiveBusy = true; archiveError = nil
        defer { isArchiveBusy = false }
        do {
            try await store.exportArchive(preview.id, to: destination)
            try? await store.closeArchive(preview.id)
            archivePreview = nil; archiveMessage = "Archive saved."
            return true
        } catch { archiveError = archiveFailureMessage(error); return false }
    }

    @discardableResult
    func restoreArchive() async -> Bool {
        guard let preview = archivePreview, !isArchiveBusy, !isImporting, !isSwitching else { return false }
        isArchiveBusy = true; archiveError = nil
        defer { isArchiveBusy = false; isSwitching = false }
        guard await flush() else { archiveError = "Save or recover your current changes before restoring."; return false }
        isSwitching = true
        do {
            let restored = try await store.commitRestore(preview.id, revision: revision + 1)
            collection = restored; revision += 1; savedRevision = revision; saveState = .saved
            archivePreview = nil; archiveMessage = "Restored as new pockets."
            return true
        } catch { archiveError = archiveFailureMessage(error); return false }
    }

    func dismissArchive() async {
        guard !isArchiveBusy else { return }
        if let preview = archivePreview { try? await store.closeArchive(preview.id) }
        archivePreview = nil; archiveError = nil; archiveMessage = nil
    }

    func cleanUnusedFiles(now: Date = .now) async {
        guard isLoaded, !isPreview, !isImporting, !isSwitching, !isArchiveBusy else { return }
        isArchiveBusy = true; archiveError = nil; archiveMessage = nil
        defer { isArchiveBusy = false }
        guard await flush() else { archiveError = "Save or recover your changes before cleaning unused files."; return }
        // Expired trash loses metadata first. The last-good/pending revisions and
        // migration backups still participate in the graph before any unlink.
        let expired = collection.trash.filter { !$0.canRestore(at: now) }
        if !expired.isEmpty {
            collection.trash.removeAll { !$0.canRestore(at: now) }
            changed()
            guard await flush() else { archiveError = "Couldn't save expired-pocket cleanup. No files were removed."; return }
        }
        var retained = Set<URL>()
        for record in deletedRecords {
            if case .reference(let reference, _) = record.record { retained.insert(reference.originalURL) }
        }
        do {
            let result = try await store.cleanupAssets(retaining: retained, now: now)
            archiveMessage = "Removed \(result.removedAssets) unused original files and \(result.removedStagingFolders) interrupted imports."
            maintenanceNotice = nil
        } catch {
            archiveError = error is CancellationError
                ? "Cleanup stopped. Files already removed were unused."
                : "Couldn't finish cleanup. Retained files stay protected. Check access and recovery records, then try again."
        }
    }

    private func archiveFailureMessage(_ error: any Error) -> String {
        if error is CancellationError { return "Cancelled. Your working library hasn't changed." }
        if let error = error as? PocketArchiveError { return error.localizedDescription }
        if let error = error as? LibraryStoreError { return error.localizedDescription }
        if (error as NSError).code == NSFileWriteOutOfSpaceError { return PocketArchiveError.noSpace.localizedDescription }
        return "Couldn't complete this file operation. Check access and free space, then try again."
    }

}
