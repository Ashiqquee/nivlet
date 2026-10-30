import AppKit
import SwiftUI

/// A title field whose initial focus is tied to actual window attachment.
/// SwiftUI defaultFocus runs when a window opens, not reliably when this panel
/// replaces its shelf with an editor. Keep the first-responder bridge here.
struct PlainTextField: NSViewRepresentable {
    @Binding var text: String
    let label: String
    let placeholder: String
    let focusRequest: Int
    var onFocusChange: (Bool) -> Void = { _ in }
    var onSubmit: () -> Void = {}
    var fontSize: CGFloat = 13
    var fontWeight: NSFont.Weight = .regular
    @Environment(\.panelTextScale) private var textScale

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> Field {
        let field = Field()
        field.isBordered = false; field.drawsBackground = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateNSView(_ field: Field, context: Context) {
        context.coordinator.parent = self
        field.setAccessibilityLabel(label)
        field.placeholderString = placeholder
        let font = NSFont.systemFont(ofSize: fontSize * textScale, weight: fontWeight)
        if field.font != font { field.font = font }
        field.textColor = .labelColor
        if field.stringValue != text { field.stringValue = text }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            field.requestFocus()
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PlainTextField
        var lastFocusRequest = 0
        init(_ parent: PlainTextField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }
        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField,
               let editor = field.currentEditor() as? NSTextView {
                editor.isAutomaticQuoteSubstitutionEnabled = false
                editor.isAutomaticDashSubstitutionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
            }
            parent.onFocusChange(true)
        }
        func controlTextDidEndEditing(_ notification: Notification) { parent.onFocusChange(false) }
        @objc func submit(_ field: NSTextField) {
            parent.text = field.stringValue
            parent.onSubmit()
        }
    }

    final class Field: NSTextField {
        private var pendingFocus = false
        override var needsPanelToBecomeKey: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); applyPendingFocus() }
        func requestFocus() { pendingFocus = true; applyPendingFocus() }
        private func applyPendingFocus() {
            guard pendingFocus, window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pendingFocus, let window = self.window else { return }
                window.makeKey()
                window.contentView?.layoutSubtreeIfNeeded()
                if window.makeFirstResponder(self) {
                    self.pendingFocus = false
                    // Include the surrounding SwiftUI well, not just the
                    // embedded control, when the enlarged editor must scroll.
                    self.scrollToVisible(self.bounds.insetBy(dx: 0, dy: -16))
                }
            }
        }
    }
}
