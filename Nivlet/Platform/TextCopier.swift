import AppKit

/// Writes reviewed text to a pasteboard. It never reads the pasteboard and never pastes.
enum TextCopier {
    /// Phase 2 policy: preserve the reviewed string, including CRLF, CR and LF.
    /// No trimming, Unicode normalisation or line-ending conversion is applied.
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
