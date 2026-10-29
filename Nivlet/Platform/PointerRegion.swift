import AppKit
import SwiftUI

/// Shows a cursor over a SwiftUI region, including while the panel is not key.
///
/// Cursor rectangles only apply in the key window, and this panel deliberately
/// stays non-key so the person's AI app keeps keyboard focus. An always-active
/// tracking area sets the cursor on entry and movement instead, then restores
/// the arrow on exit. The view never takes clicks.
struct PointerRegion: NSViewRepresentable {
    let cursor: NSCursor
    func makeNSView(context: Context) -> CursorView { CursorView(cursor: cursor) }
    func updateNSView(_ view: CursorView, context: Context) {
        view.cursor = cursor
        view.window?.invalidateCursorRects(for: view)
    }

    final class CursorView: NSView {
        var cursor: NSCursor
        private var inside = false
        init(cursor: NSCursor) { self.cursor = cursor; super.init(frame: .zero) }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func resetCursorRects() { addCursorRect(visibleRect, cursor: cursor) }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) { inside = true; cursor.set() }
        override func mouseMoved(with event: NSEvent) { if inside, NSCursor.current != cursor { cursor.set() } }
        override func cursorUpdate(with event: NSEvent) { cursor.set() }
        override func mouseExited(with event: NSEvent) {
            inside = false
            if NSCursor.current == cursor { NSCursor.arrow.set() }
        }
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            // A region removed under the pointer (for example a closing menu row) must not leave its cursor behind.
            if newWindow == nil, inside, NSCursor.current == cursor { NSCursor.arrow.set() }
            super.viewWillMove(toWindow: newWindow)
        }
    }
}

extension View {
    func shelfPointer(_ cursor: NSCursor = .pointingHand) -> some View { background(PointerRegion(cursor: cursor)) }
}
