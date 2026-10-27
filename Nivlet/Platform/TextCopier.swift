import AppKit

/// Writes reviewed text to a pasteboard. It never reads the pasteboard and never pastes.
enum TextCopier {
    /// Text exactly as it will be written. Phase 1 copies the reviewed string unchanged;
    /// Phase 2 decides the documented line-ending normalisation and applies it here only.
    static func prepared(_ text: String) -> String {
        text
    }

    /// Returns `true` when the pasteboard accepted the text.
    @discardableResult
    static func copy(_ text: String, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(prepared(text), forType: .string)
    }
}
