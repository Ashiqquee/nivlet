import CoreGraphics
import Testing
@testable import Nivlet

@Suite("Edge tab and panel geometry")
struct EdgeLayoutTests {
    /// 1440×900 display with a 25 pt menu bar and a 70 pt bottom Dock.
    private let laptop = CGRect(x: 0, y: 70, width: 1440, height: 805)
    /// External display placed to the right of the laptop.
    private let external = CGRect(x: 1440, y: 0, width: 2560, height: 1415)

    @Test("Tab sits flush against the chosen edge", arguments: ScreenEdge.allCases)
    func tabAgainstEdge(edge: ScreenEdge) {
        let frame = EdgeLayout.tabFrame(edge: edge, position: 0.5, in: laptop)
        #expect(frame.size == EdgeLayout.tabHitSize)
        switch edge {
        case .left: #expect(frame.minX == laptop.minX)
        case .right: #expect(frame.maxX == laptop.maxX)
        }
    }

    @Test("Tab stays out of the corners at its extremes", arguments: [-3.0, 0.0, 1.0, 7.0])
    func tabAvoidsCorners(position: Double) {
        let frame = EdgeLayout.tabFrame(edge: .right, position: position, in: laptop)
        #expect(frame.minY >= laptop.minY + EdgeLayout.cornerInset)
        #expect(frame.maxY <= laptop.maxY - EdgeLayout.cornerInset)
    }

    @Test("Stored tab position survives a round trip and keeps its share on another display")
    func positionRoundTrip() {
        let frame = EdgeLayout.tabFrame(edge: .right, position: 0.25, in: laptop)
        let position = EdgeLayout.tabPosition(forOriginY: frame.minY, in: laptop)
        #expect(abs(position - 0.25) < 0.0001)

        let moved = EdgeLayout.tabFrame(edge: .right, position: position, in: external)
        #expect(moved.maxX == external.maxX)
        #expect(external.contains(moved))
    }

    @Test("Very short displays centre the tab instead of failing")
    func shortDisplay() {
        let short = CGRect(x: 0, y: 0, width: 800, height: 150)
        let frame = EdgeLayout.tabFrame(edge: .left, position: 0.9, in: short)
        #expect(abs(frame.midY - short.midY) < 0.001)
    }

    @Test("Panel width stays within 320–600 points")
    func panelWidthClamped() {
        #expect(EdgeLayout.clampedPanelSize(CGSize(width: 100, height: 640), in: laptop).width == 320)
        #expect(EdgeLayout.clampedPanelSize(CGSize(width: 900, height: 640), in: laptop).width == 600)
        #expect(EdgeLayout.clampedPanelSize(CGSize(width: 380, height: 640), in: laptop).width == 380)
    }

    @Test("Panel height is clamped to the usable display")
    func panelHeightClamped() {
        let size = EdgeLayout.clampedPanelSize(CGSize(width: 380, height: 5000), in: laptop)
        #expect(size.height == laptop.height - EdgeLayout.panelGap * 2)
    }

    @Test("Panel stays inside the visible frame wherever the tab is", arguments: ScreenEdge.allCases)
    func panelInsideVisibleFrame(edge: ScreenEdge) {
        for centreY in [laptop.minY - 400, laptop.minY, laptop.midY, laptop.maxY, laptop.maxY + 400] {
            let frame = EdgeLayout.panelFrame(edge: edge, size: CGSize(width: 380, height: 640), centreY: centreY, in: laptop)
            #expect(laptop.insetBy(dx: EdgeLayout.panelGap - 0.001, dy: EdgeLayout.panelGap - 0.001).contains(frame))
        }
    }

    @Test("A panel from a detached display is re-clamped onto the remaining one")
    func reclampAfterDetach() {
        let onExternal = EdgeLayout.panelFrame(edge: .right, size: CGSize(width: 600, height: 1300), centreY: 700, in: external)
        let moved = EdgeLayout.panelFrame(edge: .right, size: onExternal.size, centreY: onExternal.midY, in: laptop)
        #expect(laptop.contains(moved))
        #expect(moved.maxX == laptop.maxX - EdgeLayout.panelGap)
    }
}
