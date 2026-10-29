import AppKit
import UniformTypeIdentifiers
import ImageIO

/// Explicit transfers prepare a disposable copy off the UI actor. The internal
/// immutable asset is never handed to a destination as an editable file.
enum ReferenceActions {
    /// Coding tools, terminals and Electron apps accept a dropped file only when the
    /// drag carries a plain file URL; a lazy file promise alone is refused there.
    /// A disposable copy is prepared off-main before dragging and offered both
    /// as a file URL and as the file's own type.
    static func dragProvider(for reference: ReferenceItem, model: PanelModel) -> NSItemProvider {
        guard let exported = model.preparedReferenceURLs.removeValue(forKey: reference.id) else {
            model.showFeedback("Preparing a file copy. Try dragging again in a moment.", persists: true)
            Task { await prepare(reference, model: model) }
            return NSItemProvider()
        }
        Task { await prepare(reference, model: model) }
        return provider(for: exported)
    }

    static func prepare(_ reference: ReferenceItem, model: PanelModel) async {
        guard model.preparedReferenceURLs[reference.id] == nil else { return }
        do {
            model.preparedReferenceURLs[reference.id] = try await exports.copy(reference)
            if model.feedback == "Preparing a file copy. Try dragging again in a moment." { model.dismissFeedback() }
        }
        catch is CancellationError { }
        catch { model.showFeedback("Couldn't prepare this file. Try Reveal in Finder again.", isError: true) }
    }

    private static let exports = ReferenceExportPreparer()

    static func provider(for exported: URL) -> NSItemProvider {
        let provider = NSItemProvider(object: exported as NSURL)
        provider.suggestedName = exported.lastPathComponent
        let type = UTType(filenameExtension: exported.pathExtension) ?? .data
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { completion in
            completion(exported, false, nil)
            return nil
        }
        return provider
    }

    /// Puts the file on the clipboard: Finder pastes the file, chat inputs paste the
    /// image (for images), and text fields and terminals paste its path.
    static func copyFile(_ reference: ReferenceItem, model: PanelModel) {
        model.showFeedback("Preparing a file copy…", persists: true)
        Task {
            do {
                let url = try await export(reference)
                let item = NSPasteboardItem()
                item.setString(url.absoluteString, forType: .fileURL)
                if reference.isImage, let image = await clipboardImage(url) {
                    item.setData(image.data, forType: .init(image.type))
                }
                item.setString(url.path(percentEncoded: false), forType: .string)
                model.transferPasteboard.clearContents()
                if model.transferPasteboard.writeObjects([item]) {
                    model.showFeedback("File copied")
                } else {
                    model.showFeedback("Couldn't copy the file. Try again.", isError: true)
                }
            } catch { model.showFeedback("Couldn't prepare this file. Try again.", isError: true) }
        }
    }

    static func reveal(_ reference: ReferenceItem, model: PanelModel) {
        model.showFeedback("Preparing a file copy…", persists: true)
        Task {
            do {
                let url = try await export(reference)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                model.showFeedback("File copy ready in Finder")
            } catch { model.showFeedback("Couldn't prepare this file. Try Reveal in Finder again.", isError: true) }
        }
    }

    private static func export(_ reference: ReferenceItem) async throws -> URL {
        try await exports.copy(reference)
    }

    nonisolated private struct ClipboardImage: Sendable { let data: Data; let type: String }

    /// Supplemental inline image data keeps its original encoded bytes. Larger
    /// images still offer the original file URL/path without an unbounded decode.
    @concurrent private static func clipboardImage(_ url: URL) async -> ClipboardImage? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 20_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return ClipboardImage(data: data, type: type as String)
    }
}

private actor ReferenceExportPreparer {
    func copy(_ reference: ReferenceItem) throws -> URL {
        // Every transfer gets a fresh copy: a destination may chmod/edit an
        // earlier export, and must not poison a future attachment.
        try FileHandoff.standard.exportCopy(of: reference.originalURL, displayName: reference.displayName)
    }
}
