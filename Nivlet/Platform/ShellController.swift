import AppKit
import Observation
import SwiftUI

/// Owns the one edge tab and one content panel, and decides when they open,
/// tuck, pin and move between displays.
@Observable
final class ShellController: NSObject {
    enum OpenSource {
        case tab
        case menu
        case shortcut
    }

    let preferences: ShellPreferences
    let kit: PocketLibrary
    let panelModel: PanelModel

    private(set) var isOpen = false
    var isPinned = false {
        didSet { updateOutsideClickMonitor() }
    }
    private var presentingChild = false {
        didSet { updateOutsideClickMonitor() }
    }
    private(set) var shortcutError: String?
    /// Bumped when displays change so menus listing them rebuild.
    private(set) var screensRevision = 0

    @ObservationIgnored private var tabPanel: EdgeTabPanel?
    @ObservationIgnored private var contentPanel: ContentPanel?
    @ObservationIgnored private var outsideClickMonitor: Any?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var hotKey: GlobalHotKey?
    /// Display the open panel is on, compared by display ID because NSScreen objects are replaced.
    @ObservationIgnored private var openDisplayID: UInt32?
    /// Guards animation completions from hiding a panel that was reopened meanwhile.
    @ObservationIgnored private var presentationID = 0

    init(
        preferences: ShellPreferences = ShellPreferences(),
        kit: PocketLibrary = PocketLibrary(),
        panelModel: PanelModel = PanelModel()
    ) {
        self.preferences = preferences
        self.kit = kit
        self.panelModel = panelModel
        super.init()
    }

    // MARK: Startup

    func start() {
        let tab = EdgeTabPanel(edge: preferences.edge)
        tab.tabView.onClick = { [weak self] in self?.toggle(source: .tab) }
        tab.tabView.onDrag = { [weak self] y in self?.dragTab(toOriginY: y) }
        tab.tabView.onDragEnded = { [weak self] in self?.finishTabDrag() }
        tabPanel = tab

        let panel = ContentPanel(rootView: PanelRootView(shell: self, kit: kit, model: panelModel))
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.handleEscape() ?? false }
        panel.onClose = { [weak self] in self?.tuck() }
        contentPanel = panel
        panelModel.focusForEditing = { [weak panel] in panel?.makeKey() }
        panel.onFind = { [weak self] in self?.panelModel.searchFocusRequest += 1 }
        panel.onNew = { [weak self] in
            guard let self else { return }
            if self.panelModel.tool == .references { self.chooseReferenceFiles() }
            else if self.panelModel.tool == .notes { self.panelModel.beginScratchpadTask() }
            else { self.panelModel.beginNew() }
        }
        panel.onUndoDelete = { [weak self] in
            guard let self, self.kit.canUndoDelete else { return false }
            self.kit.undoDelete(); return true
        }

        let hotKey = GlobalHotKey { [weak self] in self?.toggle(source: .shortcut) }
        self.hotKey = hotKey

        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.displaysChanged() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification) { $0.displaysChanged() }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.spaceChanged() }

        layoutTab()
        if preferences.shortcutEnabled { setShortcutEnabled(true) }
        Task { @concurrent in FileHandoff.standard.removeExports(olderThan: 24 * 60 * 60) }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ action: @escaping @Sendable @MainActor (ShellController) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        observers.append((center, token))
    }

    // MARK: Open and tuck

    func toggle(source: OpenSource) {
        if isOpen {
            tuck()
        } else {
            open(source: source)
        }
    }

    func open(source: OpenSource) {
        guard !isOpen, let panel = contentPanel else { return }
        // The shortcut opens where the pointer is; the tab and menu use the resting display.
        let pointerScreen = source == .shortcut ? NSScreen.underPointer : nil
        guard let screen = pointerScreen ?? restingScreen else { return }
        let visible = screen.visibleFrame
        let centreY = pointerScreen != nil && pointerScreen?.displayID != restingScreen?.displayID
            ? visible.midY
            : EdgeLayout.tabFrame(edge: preferences.edge, position: preferences.tabPosition, in: visible).midY
        let size = panelSize(in: screen)
        let target = EdgeLayout.panelFrame(edge: preferences.edge, size: size, centreY: centreY, in: visible)

        isOpen = true
        openDisplayID = screen.displayID
        tabPanel?.orderOut(nil)
        present(panel, at: target)
        // Keyboard and menu users get focus in the panel. A tab click leaves the
        // other app focused until a text field is clicked, so Copy then Command-V
        // pastes straight into the AI app.
        if source != .tab {
            panel.makeKey()
            panel.makeFirstResponder(panel.contentView)
        }
        updateOutsideClickMonitor()
    }

    /// Commits any edit in progress, then slides the panel away and restores the tab.
    func tuck() {
        guard isOpen, let panel = contentPanel else { return }
        panel.makeFirstResponder(nil)
        kit.flushSoon()
        // Keep unsaved editor drafts recoverable across click-away/tuck.
        if panelModel.draft == nil { _ = panelModel.closeChild() }
        isOpen = false
        updateOutsideClickMonitor()
        presentationID += 1
        let id = presentationID

        guard !Self.reduceMotion else {
            panel.orderOut(nil)
            layoutTab()
            return
        }
        let target = panel.frame.offsetBy(dx: preferences.edge == .right ? panel.frame.width + EdgeLayout.panelGap : -panel.frame.width - EdgeLayout.panelGap, dy: 0)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.8, 0.2)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0.7
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentationID == id else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                self.layoutTab()
            }
        }
    }

    private func present(_ panel: ContentPanel, at target: CGRect) {
        presentationID += 1
        guard !Self.reduceMotion else {
            panel.alphaValue = 1
            panel.setFrame(target, display: true)
            panel.orderFrontRegardless()
            return
        }
        // Retarget an in-flight tuck from its current position rather than
        // teleporting the window back to a fresh animation's starting frame.
        if !panel.isVisible {
            panel.alphaValue = 0.7
            let offset = preferences.edge == .right ? target.width + EdgeLayout.panelGap : -target.width - EdgeLayout.panelGap
            panel.setFrame(target.offsetBy(dx: offset, dy: 0), display: false)
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Escape closes the innermost child first, then tucks.
    func handleEscape() -> Bool {
        if panelModel.closeChild() { return true }
        guard isOpen else { return false }
        tuck()
        return true
    }

    /// Passive global monitor: it observes clicks in other apps without consuming them.
    private func updateOutsideClickMonitor() {
        let wanted = isOpen && !isPinned && !presentingChild
        if wanted, outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.tuck() }
            }
        } else if !wanted, let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: Tab placement

    private var restingScreen: NSScreen? {
        if let id = preferences.displayID, let screen = NSScreen.screens.first(where: { $0.displayID == id }) {
            return screen
        }
        return NSScreen.screens.first
    }

    private func layoutTab() {
        guard let tab = tabPanel, let screen = restingScreen else { return }
        tab.tabView.edge = preferences.edge
        tab.setFrame(
            EdgeLayout.tabFrame(edge: preferences.edge, position: preferences.tabPosition, in: screen.visibleFrame),
            display: true
        )
        if preferences.showsEdgeTab, !isOpen {
            tab.orderFrontRegardless()
        } else {
            tab.orderOut(nil)
        }
    }

    private func dragTab(toOriginY y: CGFloat) {
        guard let tab = tabPanel, let screen = restingScreen else { return }
        let travel = EdgeLayout.tabTravel(in: screen.visibleFrame)
        tab.setFrameOrigin(CGPoint(x: tab.frame.minX, y: min(max(y, travel.lowerBound), travel.upperBound)))
    }

    private func finishTabDrag() {
        guard let tab = tabPanel, let screen = restingScreen else { return }
        preferences.tabPosition = EdgeLayout.tabPosition(forOriginY: tab.frame.minY, in: screen.visibleFrame)
        layoutTab()
    }

    // MARK: Displays and Spaces

    private func displaysChanged() {
        screensRevision += 1
        layoutTab()
        guard isOpen, let panel = contentPanel else { return }
        // If the panel's display disappeared, move it to the resting display.
        let screen = NSScreen.screens.first { $0.displayID == openDisplayID } ?? restingScreen
        guard let screen else { return }
        openDisplayID = screen.displayID
        panel.setFrame(
            EdgeLayout.panelFrame(edge: preferences.edge, size: panelSize(in: screen), centreY: panel.frame.midY, in: screen.visibleFrame),
            display: true
        )
    }

    /// An unpinned panel tucks when the person changes Space; a pinned one follows.
    private func spaceChanged() {
        guard isOpen, let panel = contentPanel else { return }
        if isPinned {
            panel.orderFrontRegardless()
        } else {
            tuck()
        }
    }

    // MARK: Explicit file selection

    func chooseReferenceFiles() {
        guard kit.isLoaded, !kit.isPreview, !presentingChild, let panel = contentPanel else { return }
        presentingChild = true
        panel.makeKey()
        let picker = NSOpenPanel()
        picker.title = "Add references"
        picker.prompt = "Add files"
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.resolvesAliases = false
        picker.beginSheetModal(for: panel) { [weak self] result in
            guard let self else { return }
            self.presentingChild = false
            guard result == .OK else { return }
            let urls = picker.urls
            Task {
                let failures = await self.kit.importFiles(urls)
                if !failures.isEmpty { self.panelModel.showFeedback(failures.joined(separator: "\n"), isError: true) }
            }
        }
    }

    private func panelSize(in screen: NSScreen) -> CGSize {
        CGSize(width: preferences.panelWidth,
               height: preferences.fullHeight ? screen.visibleFrame.height - EdgeLayout.panelGap * 2 : preferences.panelHeight)
    }

    // MARK: Settings

    func setFullHeight(_ value: Bool) {
        preferences.fullHeight = value
        repositionOpenPanel()
    }

    func setEdge(_ edge: ScreenEdge) {
        guard edge != preferences.edge else { return }
        preferences.edge = edge
        layoutTab()
        repositionOpenPanel()
    }

    func setDisplay(_ displayID: UInt32?) {
        preferences.displayID = displayID
        layoutTab()
        if isOpen {
            openDisplayID = restingScreen?.displayID
            repositionOpenPanel()
        }
    }

    func setShowsEdgeTab(_ shows: Bool) {
        preferences.showsEdgeTab = shows
        layoutTab()
    }

    func resetPanelSize() {
        preferences.resetPanelSize()
        preferences.fullHeight = true
        repositionOpenPanel()
    }

    func setShortcutEnabled(_ enabled: Bool) {
        guard let hotKey else { return }
        guard enabled else {
            hotKey.unregister()
            preferences.shortcutEnabled = false
            shortcutError = nil
            return
        }
        do {
            try hotKey.register()
            preferences.shortcutEnabled = true
            shortcutError = nil
        } catch {
            preferences.shortcutEnabled = false
            shortcutError = error.message
        }
    }

    private func repositionOpenPanel() {
        guard isOpen, let panel = contentPanel else { return }
        let screen = NSScreen.screens.first { $0.displayID == openDisplayID } ?? restingScreen
        guard let screen else { return }
        let size = panelSize(in: screen)
        panel.setFrame(
            EdgeLayout.panelFrame(edge: preferences.edge, size: size, centreY: panel.frame.midY, in: screen.visibleFrame),
            display: true,
            animate: !Self.reduceMotion
        )
    }
}

extension ShellController: NSWindowDelegate {
    /// Command-Tab or clicking another app's window while editing tucks an unpinned panel.
    func windowDidResignKey(_ notification: Notification) {
        guard isOpen, !isPinned, !presentingChild else { return }
        tuck()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = contentPanel else { return }
        preferences.panelWidth = panel.frame.width
        if let screen = panel.screen, abs(panel.frame.height - (screen.visibleFrame.height - EdgeLayout.panelGap * 2)) > 4 {
            preferences.fullHeight = false
        }
        preferences.panelHeight = panel.frame.height
        // Keep the panel against its edge whichever side was dragged.
        repositionOpenPanel()
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static var underPointer: NSScreen? {
        let point = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
