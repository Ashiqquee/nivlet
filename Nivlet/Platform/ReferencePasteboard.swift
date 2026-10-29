import AppKit
import UniformTypeIdentifiers

enum ReferencePasteboard {
    private static var detected: [NSPasteboard.Name: (change: Int, hasFile: Bool)] = [:]
    /// Metadata only. Called for menu validation, never reads item data.
    static func canPaste(from pasteboard: NSPasteboard) -> Bool {
        let image = pasteboard.availableType(from: [.png, .tiff]) != nil
        guard pasteboard.availableType(from: [.fileURL]) != nil else { return image }
        if #available(macOS 15.4, *) {
            let name = pasteboard.name, change = pasteboard.changeCount
            if let known = detected[name], known.change == change { return image || known.hasFile }
            detected[name] = (change, true)
            // This SDK exposes the refined ObjC spelling (no Swift overlay).
            // The callback supplies only content-type metadata, never contents.
            pasteboard.__detectMetadata(forTypes: [.__contentType]) { metadata, error in
                // Missing metadata (for example, a file that disappeared) is
                // inconclusive. Keep the declared file URL actionable so the
                // importer can report the failure and offer source recovery.
                let hasFile = (metadata?[.__contentType] as? UTType)?.conforms(to: .item) ?? true
                Task { @MainActor in
                    if detected[name]?.change == change { detected[name] = (change, hasFile) }
                }
            }
        }
        // Legacy systems and pending/failed metadata detection use declared
        // pasteboard types only. The importer independently validates every URL.
        return true
    }

    /// Only call inside the responder chain's user-initiated paste: action.
    /// File URLs take precedence over rendered image representations, preserving
    /// original files and multiple names. Plain text/remote URLs are not imports.
    static func readForExplicitPaste(from pasteboard: NSPasteboard) -> [ReferenceImportSource] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty { return urls.map(ReferenceImportSource.file) }
        if pasteboard.availableType(from: [.fileURL]) != nil {
            let declared = (pasteboard.pasteboardItems ?? []).compactMap { item -> ReferenceImportSource? in
                guard let raw = item.string(forType: .fileURL), let url = URL(string: raw), url.isFileURL else { return nil }
                return .file(url)
            }
            // A sandbox may refuse to resolve a disappeared file as NSURL. Keep
            // its declared path for an honest failure/reselection result; never
            // silently consume a supported paste with no visible outcome.
            return declared.isEmpty ? [.unavailable(name: "Copied file")] : declared
        }
        let images: [ReferenceImportSource] = (pasteboard.pasteboardItems ?? []).compactMap { item in
            for (type, suffix) in [(NSPasteboard.PasteboardType.png, "png"), (.tiff, "tiff")] {
                if let bytes = item.data(forType: type) {
                    return .image(bytes, name: "Pasted image.\(suffix)")
                }
            }
            return nil
        }
        if images.isEmpty, pasteboard.availableType(from: [.png, .tiff]) != nil { return [.unavailable(name: "Copied image")] }
        return images
    }
}
