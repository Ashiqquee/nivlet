import AppKit
import UniformTypeIdentifiers

/// Explicit transfers prepare a disposable copy off the UI actor. The internal
/// immutable asset is never handed to a destination as an editable file.
enum ReferenceActions {
    static func dragProvider(for reference: ReferenceItem, model: PanelModel) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = reference.displayName
        let type = UTType(filenameExtension: (reference.displayName as NSString).pathExtension) ?? .data
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 1)
            let task = Task { @concurrent in
                defer { progress.completedUnitCount = 1 }
                do {
                    let url = try FileHandoff.standard.exportCopy(of: reference.originalURL, displayName: reference.displayName)
                    completion(url, false, nil)
                } catch { completion(nil, false, error) }
            }
            progress.cancellationHandler = { task.cancel() }
            return progress
        }
        return provider
    }

    static func reveal(_ reference: ReferenceItem, model: PanelModel) {
        Task {
            do {
                let url = try await export(reference)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch { model.showFeedback("Couldn't prepare this file. Try Reveal in Finder again.", isError: true) }
        }
    }

    @concurrent private static func export(_ reference: ReferenceItem) async throws -> URL {
        try FileHandoff.standard.exportCopy(of: reference.originalURL, displayName: reference.displayName)
    }
}
