import AppKit
import SwiftUI

/// The open toolkit. A non-activating panel: it floats beside the person's AI
/// app and becomes key only when a control needs the keyboard (a text field),
/// so clicking Copy leaves the AI app focused and ready for Command-V.
final class ContentPanel: NSPanel {
    /// Escape handling. Returns `true` when the shell consumed the key.
    var onEscape: () -> Bool = { false }
    /// Command-W: tuck rather than close.
    var onClose: () -> Void = {}
    var onFind: () -> Void = {}
    var onNew: () -> Void = {}
    var onUndoDelete: () -> Bool = { false }
    var canPasteReferences: () -> Bool = { false }
    var onPasteReferences: () -> Void = {}

    @objc func paste(_ sender: Any?) {
        if canPasteReferences() { onPasteReferences() }
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)) { return canPasteReferences() }
        return super.validateUserInterfaceItem(item)
    }
    /// Launcher-style list keys. Returns `true` when the shelf used the key.
    var onListKey: (ShelfKey) -> Bool = { _ in false }

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: CGRect(origin: .zero, size: EdgeLayout.defaultPanelSize),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        title = "Nivlet"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // The tool rail's labelled Collapse button replaces the close button.
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        isFloatingPanel = true
        level = .floating
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        minSize = CGSize(width: EdgeLayout.panelWidthRange.lowerBound, height: EdgeLayout.panelMinHeight)
        maxSize = CGSize(width: EdgeLayout.panelWidthRange.upperBound, height: .greatestFiniteMagnitude)
        let hostingView = FirstClickHostingView(rootView: rootView)
        // EdgeLayout owns the panel bounds. A tool's ideal content size must
        // not override the shell's 320–600 pt resize range.
        hostingView.sizingOptions = []
        contentView = hostingView
        setAccessibilityLabel("Nivlet panel")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // Intercept Escape before NSTextView turns it into word completion,
        // but leave it alone while an input method is composing text.
        if event.type == .keyDown, event.keyCode == 53,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock).isEmpty {
            let composing = (firstResponder as? NSTextView)?.hasMarkedText() ?? false
            if !composing, onEscape() { return }
        }
        // Arrow keys and Return drive the shelf list while the search field (a
        // single-line field editor) or no text view has focus. Multi-line
        // editors and input-method composition keep their normal behavior.
        if event.type == .keyDown,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]).isEmpty {
            let key: ShelfKey? = switch event.keyCode {
            case 126: .up
            case 125: .down
            case 36, 76: .enter
            default: nil
            }
            let textView = firstResponder as? NSTextView
            let editingText = textView.map { $0.hasMarkedText() || !$0.isFieldEditor } ?? false
            let shelfOwnsFocus = firstResponder === contentView || textView?.isFieldEditor == true
            if let key, !editingText, shelfOwnsFocus, onListKey(key) { return }
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let pasteFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        if pasteFlags == .command, event.charactersIgnoringModifiers?.lowercased() == "v", canPasteReferences() {
            // Keep the standard, user-initiated paste: action as the platform
            // boundary; file/image data never comes from a custom paste button.
            return NSApp.sendAction(#selector(paste(_:)), to: self, from: self)
        }
        if super.performKeyEquivalent(with: event) { return true }
        // An accessory app may not be active while this panel is key, so the
        // standard editing commands are routed here as well as the main menu.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let action: Selector? = switch (flags, key) {
        case (.command, "x"): #selector(NSText.cut(_:))
        case (.command, "c"): #selector(NSText.copy(_:))
        case (.command, "v"): #selector(NSText.paste(_:))
        case (.command, "a"): #selector(NSText.selectAll(_:))
        case (.command, "z"): Selector(("undo:"))
        case ([.command, .shift], "z"): Selector(("redo:"))
        default: nil
        }
        if flags == .command, key == "f" { onFind(); return true }
        let listKey: ShelfKey? = switch (flags, key) {
        case (.command, "k"): .actions
        case (.command, "o"): .open
        case (.command, "e"): .edit
        case (.command, "d"): .duplicate
        case ([.command, .shift], "f"): .favorite
        case (.command, _) where event.keyCode == 51: .delete
        default: nil
        }
        if let listKey, onListKey(listKey) { return true }
        if flags == .command, key == "n" { onNew(); return true }
        if let action {
            if NSApp.sendAction(action, to: nil, from: self) { return true }
            if flags == .command, key == "z" { return onUndoDelete() }
            return false
        }
        if flags == .command, key == "w" {
            onClose()
            return true
        }
        return false
    }
}

/// Lets the first click on a control work even while the panel is not key.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
