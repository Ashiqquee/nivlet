import AppKit
import SwiftUI

/// Cursor rectangles are owned by AppKit. No global cursor stack or fake cursor.
struct PointerRegion: NSViewRepresentable {
    let cursor: NSCursor
    func makeNSView(context: Context) -> CursorView { CursorView(cursor: cursor) }
    func updateNSView(_ view: CursorView, context: Context) {
        view.cursor = cursor
        view.window?.invalidateCursorRects(for: view)
    }

    final class CursorView: NSView {
        var cursor: NSCursor
        init(cursor: NSCursor) { self.cursor = cursor; super.init(frame: .zero) }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func resetCursorRects() { addCursorRect(visibleRect, cursor: cursor) }
    }
}

extension View {
    func shelfPointer(_ cursor: NSCursor = .pointingHand) -> some View { background(PointerRegion(cursor: cursor)) }
}
