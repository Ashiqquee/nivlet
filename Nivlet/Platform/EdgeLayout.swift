import CoreGraphics

/// Which side of the display holds the tab and the open panel.
enum ScreenEdge: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left Edge"
        case .right: "Right Edge"
        }
    }
}

/// Pure geometry for the edge tab and panel, so display changes can be tested
/// without real hardware. All rectangles use AppKit screen coordinates
/// (origin at the bottom left, y grows upward).
enum EdgeLayout {
    /// Clickable area of the tab window. The drawn tab is smaller.
    static let tabHitSize = CGSize(width: 36, height: 72)
    static let tabVisibleSize = CGSize(width: 10, height: 44)
    /// Keeps the tab out of hot corners, the menu bar and the Dock corner.
    static let cornerInset: CGFloat = 72
    /// Space between the open panel and the display edge.
    static let panelGap: CGFloat = 8
    static let panelWidthRange: ClosedRange<CGFloat> = 320...600
    static let panelMinHeight: CGFloat = 360
    static let defaultPanelSize = CGSize(width: 380, height: 640)

    /// Frame of the tab window. `position` runs from 0 (lowest allowed point)
    /// to 1 (highest allowed point) and is clamped.
    static func tabFrame(edge: ScreenEdge, position: Double, in visible: CGRect) -> CGRect {
        let range = tabTravel(in: visible)
        let fraction = CGFloat(min(max(position, 0), 1))
        let y = range.lowerBound + (range.upperBound - range.lowerBound) * fraction
        let x = switch edge {
        case .left: visible.minX
        case .right: visible.maxX - tabHitSize.width
        }
        return CGRect(x: x, y: y, width: tabHitSize.width, height: tabHitSize.height)
    }

    /// Converts a dragged tab origin back into a stored position.
    static func tabPosition(forOriginY y: CGFloat, in visible: CGRect) -> Double {
        let range = tabTravel(in: visible)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return Double(min(max((y - range.lowerBound) / span, 0), 1))
    }

    /// Lowest and highest tab origin. Collapses to the centre on very short displays.
    static func tabTravel(in visible: CGRect) -> ClosedRange<CGFloat> {
        let low = visible.minY + cornerInset
        let high = visible.maxY - cornerInset - tabHitSize.height
        if high >= low { return low...high }
        let centre = visible.midY - tabHitSize.height / 2
        return centre...centre
    }

    /// Clamps a requested panel size to the allowed width range and the usable display.
    static func clampedPanelSize(_ size: CGSize, in visible: CGRect) -> CGSize {
        let maxWidth = max(visible.width - panelGap * 2, 1)
        let maxHeight = max(visible.height - panelGap * 2, 1)
        let width = min(min(max(size.width, panelWidthRange.lowerBound), panelWidthRange.upperBound), maxWidth)
        let height = min(max(size.height, panelMinHeight), maxHeight)
        return CGSize(width: width, height: height)
    }

    /// Panel frame against the chosen edge, vertically centred on `centreY` where it fits.
    static func panelFrame(edge: ScreenEdge, size: CGSize, centreY: CGFloat, in visible: CGRect) -> CGRect {
        let size = clampedPanelSize(size, in: visible)
        let x = switch edge {
        case .left: visible.minX + panelGap
        case .right: visible.maxX - panelGap - size.width
        }
        let lowest = visible.minY + panelGap
        let highest = visible.maxY - panelGap - size.height
        let y = min(max(centreY - size.height / 2, lowest), max(highest, lowest))
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
