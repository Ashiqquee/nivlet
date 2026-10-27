import AppKit
import QuartzCore

/// The small screen-edge tab. Never takes keyboard focus, never opens on hover.
final class EdgeTabPanel: NSPanel {
    let tabView: EdgeTabView

    init(edge: ScreenEdge) {
        tabView = EdgeTabView(edge: edge)
        super.init(
            contentRect: CGRect(origin: .zero, size: EdgeLayout.tabHitSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = tabView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws the visible tab inside a larger hit area and separates click from vertical drag.
final class EdgeTabView: NSView {
    var edge: ScreenEdge {
        didSet { updateHandle(animated: false) }
    }
    var onClick: () -> Void = {}
    /// Called with the proposed window origin y while dragging.
    var onDrag: (CGFloat) -> Void = { _ in }
    var onDragEnded: () -> Void = {}

    private var mouseDownScreenY: CGFloat?
    private var windowStartY: CGFloat = 0
    private var isDragging = false
    private let surfaceLayer = CAShapeLayer()
    private let gripLayer = CAShapeLayer()
    private let chevronLayer = CALayer()
    private var isHovered = false

    init(edge: ScreenEdge) {
        self.edge = edge
        super.init(frame: CGRect(origin: .zero, size: EdgeLayout.tabHitSize))
        wantsLayer = true
        layer?.addSublayer(surfaceLayer)
        layer?.addSublayer(gripLayer)
        layer?.addSublayer(chevronLayer)
        updateHandle(animated: false)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Open Nivlet")
        setAccessibilityHelp("Opens your instructions, prompts, references and notes.")
        toolTip = "Open Nivlet"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func accessibilityPerformPress() -> Bool {
        onClick()
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }

    private func setHovered(_ hovered: Bool) {
        isHovered = hovered
        updateHandle(animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { updateHandle(animated: false) }
    override func layout() { super.layout(); updateHandle(animated: false) }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHandle(animated: false)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownScreenY = NSEvent.mouseLocation.y
        windowStartY = window?.frame.minY ?? 0
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startY = mouseDownScreenY else { return }
        let delta = NSEvent.mouseLocation.y - startY
        if !isDragging, abs(delta) < 4 { return }
        isDragging = true
        NSCursor.closedHand.set()
        onDrag(windowStartY + delta)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownScreenY = nil; isDragging = false
            window?.invalidateCursorRects(for: self)
        }
        if isDragging {
            onDragEnded()
        } else if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick()
        }
    }

    /// A quiet grip at rest; the inward arrow appears only during deliberate hover.
    /// Path and opacity animations retarget their current presentation values.
    private func updateHandle(animated: Bool) {
        guard layer != nil else { return }
        let depth: CGFloat = isHovered ? 18 : EdgeLayout.tabVisibleSize.width
        let height = EdgeLayout.tabVisibleSize.height
        let radius: CGFloat = 8
        let x = edge == .right ? bounds.maxX - depth : bounds.minX - radius
        let rect = CGRect(x: x, y: bounds.midY - height / 2, width: depth + radius, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let gripX = edge == .right ? bounds.maxX - 5 : bounds.minX + 5
        let grip = CGPath(roundedRect: CGRect(x: gripX - 1, y: bounds.midY - 7, width: 2, height: 14),
                          cornerWidth: 1, cornerHeight: 1, transform: nil)
        let arrowAlpha: Float = isHovered ? 1 : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if animated {
            animate(surfaceLayer, key: "path", to: path)
            animate(gripLayer, key: "opacity", to: 1 - arrowAlpha)
            animate(chevronLayer, key: "opacity", to: arrowAlpha)
        }
        surfaceLayer.path = path
        gripLayer.path = grip
        gripLayer.opacity = 1 - arrowAlpha
        chevronLayer.opacity = arrowAlpha
        let scale = window?.backingScaleFactor ?? 2
        surfaceLayer.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1 : 1 / scale
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            surfaceLayer.fillColor = NSColor(white: dark ? 0.10 : 0.96, alpha: 1).cgColor
            surfaceLayer.strokeColor = (NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? NSColor.labelColor : NSColor.separatorColor).cgColor
            gripLayer.fillColor = NSColor.labelColor.withAlphaComponent(0.7).cgColor
            let symbol = edge == .right ? "chevron.left" : "chevron.right"
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
                .applying(.init(paletteColors: [.labelColor]))
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            chevronLayer.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        let arrowX = edge == .right ? bounds.maxX - 13 : bounds.minX + 5
        chevronLayer.frame = CGRect(x: arrowX, y: bounds.midY - 5, width: 6, height: 10)
        chevronLayer.contentsGravity = .resizeAspect
        chevronLayer.contentsScale = scale
        CATransaction.commit()
    }

    private func animate(_ target: CALayer, key: String, to value: Any) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = target.presentation()?.value(forKeyPath: key) ?? target.value(forKeyPath: key)
        animation.toValue = value
        animation.duration = 0.15
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
        target.add(animation, forKey: key)
    }
}
