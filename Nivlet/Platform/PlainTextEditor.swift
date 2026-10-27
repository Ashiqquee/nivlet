import AppKit
import SwiftUI

/// An ordinary native text view with undo and selection, without the smart
/// punctuation substitutions that would silently rewrite prompts or pasted code.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let label: String
    var lineSpacing: CGFloat = 4
    var focusRequest = 0
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let view = EditorTextView(frame: .zero)
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.drawsBackground = false
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = .labelColor
        view.insertionPointColor = .labelColor
        view.textContainerInset = NSSize(width: 4, height: 6)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        view.defaultParagraphStyle = paragraph
        view.typingAttributes = [.font: NSFont.preferredFont(forTextStyle: .body), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        view.string = text
        view.setAccessibilityLabel(label)
        view.focusChanged = { [weak coordinator = context.coordinator] focused in coordinator?.parent.onFocusChange(focused) }
        view.delegate = context.coordinator
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? EditorTextView else { return }
        view.setAccessibilityLabel(label)
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                view.window?.makeKey()
                view.window?.makeFirstResponder(view)
            }
        }
        if view.string != text {
            let selection = view.selectedRange()
            view.string = text
            let count = (text as NSString).length
            view.setSelectedRange(NSRange(location: min(selection.location, count), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        var lastFocusRequest = 0
        init(_ parent: PlainTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }

    final class EditorTextView: NSTextView {
        var focusChanged: (Bool) -> Void = { _ in }
        override var needsPanelToBecomeKey: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func becomeFirstResponder() -> Bool {
            let accepted = super.becomeFirstResponder()
            if accepted { DispatchQueue.main.async { [weak self] in self?.focusChanged(true) } }
            return accepted
        }
        override func resignFirstResponder() -> Bool {
            let accepted = super.resignFirstResponder()
            if accepted { DispatchQueue.main.async { [weak self] in self?.focusChanged(false) } }
            return accepted
        }
    }
}
