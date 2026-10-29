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
    /// One dot per tool, top to bottom, in the tools' accent hues.
    var markColors: [NSColor] = [.systemOrange, .systemBlue, .systemGreen] {
        didSet { updateHandle(animated: false) }
    }

    private var mouseDownScreenY: CGFloat?
    private var windowStartY: CGFloat = 0
    private var isDragging = false
    private let surfaceLayer = CAShapeLayer()
    private let dotLayers = (0..<3).map { _ in CALayer() }
    private let chevronLayer = CALayer()
    private var isHovered = false

    init(edge: ScreenEdge) {
        self.edge = edge
        super.init(frame: CGRect(origin: .zero, size: EdgeLayout.tabHitSize))
        wantsLayer = true
        layer?.addSublayer(surfaceLayer)
        dotLayers.forEach { layer?.addSublayer($0) }
        layer?.addSublayer(chevronLayer)
        #if DEBUG
        // Capture hook: `-NivletTabHover YES` draws the hover state without moving the pointer.
        isHovered = UserDefaults.standard.bool(forKey: "NivletTabHover")
        #endif
        updateHandle(animated: false)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Open Nivlet")
        setAccessibilityHelp("Opens your prompts, references and scratchpad.")
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
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    // This panel never becomes key, so cursor rectangles alone would not apply.
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func cursorUpdate(with event: NSEvent) { if !isDragging { NSCursor.pointingHand.set() } }

    override func mouseEntered(with event: NSEvent) { setHovered(true); NSCursor.pointingHand.set() }
    override func mouseExited(with event: NSEvent) {
        setHovered(false)
        if !isDragging { NSCursor.arrow.set() }
    }

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
            if isHovered { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        if isDragging {
            onDragEnded()
        } else if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick()
        }
    }

    /// Three tool dots at rest. On deliberate hover the tab deepens and the dots
    /// gather into its centre, where the inward chevron grows in.
    /// Animations retarget their current presentation values.
    private func updateHandle(animated: Bool) {
        guard layer != nil else { return }
        let depth: CGFloat = isHovered ? 20 : EdgeLayout.tabVisibleSize.width
        let height = EdgeLayout.tabVisibleSize.height
        let radius: CGFloat = 8
        let x = edge == .right ? bounds.maxX - depth : bounds.minX - radius
        let rect = CGRect(x: x, y: bounds.midY - height / 2, width: depth + radius, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let centreX = edge == .right ? bounds.maxX - depth / 2 : bounds.minX + depth / 2
        let centre = CGPoint(x: centreX, y: bounds.midY)
        let dotSize: CGFloat = 3.5, dotSpacing: CGFloat = 6
        let dotTransform = isHovered ? CATransform3DMakeScale(0.3, 0.3, 1) : CATransform3DIdentity
        let arrowTransform = isHovered ? CATransform3DIdentity : CATransform3DMakeScale(0.5, 0.5, 1)
        let dotAlpha: Float = isHovered ? 0 : 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The window server resets the pointer to an arrow while this non-opaque
        // window's shape animates; restore the hand once the morph settles.
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, animated, isHovered, !isDragging else { return }
            NSCursor.pointingHand.set()
        }
        if animated {
            animate(surfaceLayer, key: "path", to: path)
            animate(chevronLayer, key: "opacity", to: 1 - dotAlpha)
            animate(chevronLayer, key: "position", to: NSValue(point: centre))
            animate(chevronLayer, key: "transform", to: NSValue(caTransform3D: arrowTransform))
        }
        surfaceLayer.path = path
        for (index, dot) in dotLayers.enumerated() {
            let rest = CGPoint(x: centreX, y: bounds.midY + CGFloat(1 - index) * dotSpacing)
            let position = isHovered ? centre : rest
            if animated {
                animate(dot, key: "position", to: NSValue(point: position))
                animate(dot, key: "opacity", to: dotAlpha)
                animate(dot, key: "transform", to: NSValue(caTransform3D: dotTransform))
            }
            dot.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            dot.cornerRadius = dotSize / 2
            dot.position = position
            dot.opacity = dotAlpha
            dot.transform = dotTransform
            dot.backgroundColor = markColors.indices.contains(index) ? markColors[index].cgColor : nil
        }
        chevronLayer.bounds = CGRect(x: 0, y: 0, width: 7, height: 12)
        chevronLayer.position = centre
        chevronLayer.opacity = 1 - dotAlpha
        chevronLayer.transform = arrowTransform
        let scale = window?.backingScaleFactor ?? 2
        surfaceLayer.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1 : 1 / scale
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            surfaceLayer.fillColor = NSColor(white: dark ? 0.12 : 0.97, alpha: 1).cgColor
            surfaceLayer.strokeColor = (NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? NSColor.labelColor : NSColor.separatorColor).cgColor
            let symbol = edge == .right ? "chevron.left" : "chevron.right"
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
                .applying(.init(paletteColors: [.labelColor]))
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            chevronLayer.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        chevronLayer.contentsGravity = .resizeAspect
        chevronLayer.contentsScale = scale
        CATransaction.commit()
    }

    private func animate(_ target: CALayer, key: String, to value: Any) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = target.presentation()?.value(forKeyPath: key) ?? target.value(forKeyPath: key)
        animation.toValue = value
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
        target.add(animation, forKey: key)
    }
}
