import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

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
    let loginItem = LoginItem()

    private(set) var isOpen = false
    private(set) var showsIntroduction = false
    var introductionShowsGuide = false
    var isPreparingIntroduction = false
    var isPinned = false {
        didSet { updateOutsideClickMonitor() }
    }
    private var childIsPresented: Bool {
        isPreparingIntroduction || presentingChild || archivePicker != nil || referencePicker != nil || panelModel.archivePresentation != nil || contentPanel?.attachedSheet != nil
    }
    private var presentingChild = false {
        didSet { updateOutsideClickMonitor() }
    }
    private(set) var shortcutError: String?
    /// Bumped when displays change so menus listing them rebuild.
    private(set) var screensRevision = 0

    @ObservationIgnored private var tabPanel: EdgeTabPanel?
    @ObservationIgnored private var contentPanel: ContentPanel?
    @ObservationIgnored private var archivePicker: NSSavePanel?
    @ObservationIgnored private var referencePicker: NSOpenPanel?
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
        BackgroundCursor.enable()
        NSApp.appearance = preferences.appearance.nsAppearance
        let tab = EdgeTabPanel(edge: preferences.edge)
        tab.tabView.onClick = { [weak self] in self?.toggle(source: .tab) }
        tab.tabView.onDrag = { [weak self] y in self?.dragTab(toOriginY: y) }
        tab.tabView.onDragEnded = { [weak self] in self?.finishTabDrag() }
        tab.tabView.markColors = PanelTool.allCases.map { NSColor($0.tint) }
        tabPanel = tab

        let panel = ContentPanel(rootView: PanelRootView(shell: self, kit: kit, model: panelModel))
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.handleEscape() ?? false }
        panel.onClose = { [weak self] in self?.tuck() }
        contentPanel = panel
        panel.canPasteReferences = { [weak self] in
            guard let self, !self.showsIntroduction else { return false }
            return self.panelModel.archivePresentation == nil && self.panelModel.tool == .references && self.panelModel.inspector == nil && self.kit.isLoaded && !self.kit.isPreview && !self.kit.isImporting && !self.kit.isSwitching && self.panelModel.query.isEmpty && ReferencePasteboard.canPaste(from: self.panelModel.transferPasteboard)
        }
        panel.onPasteReferences = { [weak self] in
            guard let self else { return }
            let sources = ReferencePasteboard.readForExplicitPaste(from: self.panelModel.transferPasteboard)
            Task { await self.kit.importSources(sources) }
        }
        panelModel.focusForEditing = { [weak panel] in panel?.makeKey() }
        panel.onFind = { [weak self] in
            guard let self, !self.showsIntroduction, self.panelModel.archivePresentation == nil else { return }
            self.panelModel.searchFocusRequest += 1
        }
        panel.onNew = { [weak self] in
            guard let self, !self.showsIntroduction, self.panelModel.archivePresentation == nil else { return }
            if self.panelModel.tool == .references { self.chooseReferenceFiles() }
            else if self.panelModel.tool == .notes { self.panelModel.beginScratchpadTask() }
            else { self.panelModel.beginNew() }
        }
        panel.onListKey = { [weak self] key in
            guard let self, !self.showsIntroduction else { return false }
            return self.panelModel.handle(key, kit: self.kit)
        }
        panel.onUndoDelete = { [weak self] in
            guard let self, !self.showsIntroduction, self.panelModel.archivePresentation == nil, self.kit.canUndoDelete else { return false }
            self.kit.undoDelete(); return true
        }

        let hotKey = GlobalHotKey { [weak self] in self?.toggle(source: .shortcut) }
        self.hotKey = hotKey

        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.displaysChanged() }
        observe(NotificationCenter.default, NSMenu.didBeginTrackingNotification) { $0.routePasteMenu() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification) { $0.displaysChanged() }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.spaceChanged() }

        layoutTab()
        if preferences.shortcutEnabled { setShortcutEnabled(true) }
        Task { @concurrent in FileHandoff.standard.removeExports(olderThan: 24 * 60 * 60) }
        // Completed to-dos leave a day after they were ticked, even while tucked.
        Task { [weak self] in
            while true {
                do { try await Task.sleep(for: .seconds(10 * 60)) } catch { return }
                guard let self else { return }
                self.kit.expireCompletedTasks()
            }
        }
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
        let target = EdgeLayout.panelFrame(edge: preferences.edge, size: size, centreY: centreY, in: panelArea(on: screen), flush: preferences.fullHeight)

        isOpen = true
        openDisplayID = screen.displayID
        kit.expireCompletedTasks()
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
        guard isOpen, !childIsPresented, let panel = contentPanel else { return }
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
            context.duration = 0.14
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
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Escape closes the innermost child first, then tucks.
    func handleEscape() -> Bool {
        if showsIntroduction {
            if introductionShowsGuide { introductionShowsGuide = false; return true }
            if !isPreparingIntroduction { finishIntroduction() }
            return true
        }
        if panelModel.archivePresentation != nil { return false } // Let the preview's Cancel shortcut handle Escape.
        if panelModel.closeChild() { return true }
        if !panelModel.query.isEmpty { panelModel.query = ""; return true }
        guard isOpen else { return false }
        tuck()
        return true
    }

    /// Passive global monitor: it observes clicks in other apps without consuming them.
    private func updateOutsideClickMonitor() {
        let wanted = isOpen && !isPinned && !childIsPresented
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
            EdgeLayout.panelFrame(edge: preferences.edge, size: panelSize(in: screen), centreY: panel.frame.midY, in: panelArea(on: screen), flush: preferences.fullHeight),
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

    private func routePasteMenu() {
        guard let panel = contentPanel, let menu = NSApp.mainMenu else { return }
        let usesReferences = panel.isKeyWindow && panel.canPasteReferences()
        func route(_ menu: NSMenu) {
            for item in menu.items {
                if item.action == #selector(NSText.paste(_:)) { item.target = usesReferences ? panel : nil }
                if let submenu = item.submenu { route(submenu) }
            }
        }
        route(menu)
    }

    func chooseReferenceFiles() {
        chooseReferenceFiles(retryID: nil)
    }

    func chooseReferenceFileForRetry(_ id: UUID) {
        chooseReferenceFiles(retryID: id)
    }

    private func chooseReferenceFiles(retryID: UUID?) {
        guard kit.isLoaded, !kit.isPreview, panelModel.archivePresentation == nil, !presentingChild, let panel = contentPanel else { return }
        presentingChild = true
        panel.makeKey()
        let picker = NSOpenPanel()
        referencePicker = picker
        picker.title = "Add references"
        picker.prompt = "Add files"
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = retryID == nil
        picker.resolvesAliases = false
        if let retryID, let original = kit.originalImportURL(retryID) { picker.directoryURL = original.deletingLastPathComponent() }
        // A system file browser is wider than this utility. An attached sheet
        // can move/resize its narrow parent; keep it in an independent window.
        let visible = (panel.screen ?? restingScreen)?.visibleFrame ?? panel.frame
        let size = CGSize(width: min(820, visible.width - 32), height: min(520, visible.height - 32))
        picker.setContentSize(size)
        picker.level = .modalPanel
        panel.ignoresMouseEvents = true
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [weak self] result in
            guard let self else { return }
            self.referencePicker = nil
            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
            panel.makeKey()
            self.presentingChild = false
            guard result == .OK else { return }
            let urls = picker.urls
            Task {
                if let retryID, let url = urls.first { await self.kit.replaceImportSource(id: retryID, with: url) }
                else { await self.kit.importFiles(urls) }
            }
        }
        let frame = picker.frame
        picker.setFrameOrigin(CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2))
    }

    func focusArchivePreview() {
        guard let panel = contentPanel else { return }
        panel.makeKey(); panel.makeFirstResponder(panel.contentView)
    }

    func chooseArchiveDestination(completion: @escaping (URL?) -> Void) {
        let picker = NSSavePanel()
        picker.title = "Save Nivlet archive"; picker.prompt = "Save archive"
        picker.nameFieldStringValue = "Nivlet pockets.nivlet"
        picker.allowedContentTypes = [.init(filenameExtension: "nivlet") ?? .data]
        presentArchivePicker(picker) { response in completion(response == .OK ? picker.url : nil) }
    }

    func chooseArchiveToRestore() {
        let picker = NSOpenPanel()
        picker.title = "Choose Nivlet archive"; picker.prompt = "Preview archive"
        picker.canChooseFiles = true; picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
        picker.resolvesAliases = false
        picker.allowedContentTypes = [.init(filenameExtension: "nivlet") ?? .data]
        presentArchivePicker(picker) { [weak self] response in
            if response == .OK, let url = picker.url { self?.panelModel.archivePresentation = ArchivePresentation(mode: .restore(url)) }
        }
    }

    private func presentArchivePicker(_ picker: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        guard archivePicker == nil, referencePicker == nil, let panel = contentPanel,
              !presentingChild || panelModel.archivePresentation != nil else { completion(.cancel); return }
        // A reviewed archive preview may request Save. Keep overlapping native
        // pickers blocked and protect the utility while the browser is active.
        let parent = panel.attachedSheet ?? panel
        presentingChild = true; archivePicker = picker
        parent.makeKey(); picker.level = .modalPanel; parent.ignoresMouseEvents = true
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [weak self] response in
            guard let self else { return }
            self.archivePicker = nil; parent.ignoresMouseEvents = false
            parent.orderFrontRegardless(); parent.makeKey()
            self.presentingChild = panel.attachedSheet != nil
            completion(response)
        }
        if let visible = (panel.screen ?? restingScreen)?.visibleFrame {
            let frame = picker.frame
            picker.setFrameOrigin(CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2))
        }
    }

    private func panelSize(in screen: NSScreen) -> CGSize {
        CGSize(width: preferences.panelWidth,
               height: preferences.fullHeight ? panelArea(on: screen).height : preferences.panelHeight)
    }

    /// Where the panel may sit: the usable area, plus the Dock's strip when a
    /// full-height panel is docked and the Dock isn't currently showing.
    private func panelArea(on screen: NSScreen) -> CGRect {
        guard preferences.fullHeight else { return screen.visibleFrame }
        return EdgeLayout.dockingArea(visible: screen.visibleFrame, screen: screen.frame,
                                      bottomDockShowing: screen.isBottomDockShowing)
    }

    // MARK: Settings

    func libraryDidLoad() {
        kit.expireCompletedTasks()
        guard kit.isLoaded, !kit.isPreview, !preferences.hasCompletedIntroduction else { return }
        if kit.isBlankLibrary { showIntroduction() }
        else { preferences.hasCompletedIntroduction = true }
    }

    func showIntroduction() {
        guard !childIsPresented else { return }
        introductionShowsGuide = false
        showsIntroduction = true
        open(source: .menu)
        focusArchivePreview()
    }

    func finishIntroduction() {
        introductionShowsGuide = false
        preferences.hasCompletedIntroduction = true
        showsIntroduction = false
        panelModel.searchFocusRequest += 1
    }

    /// The shell owns this guard, so removing the introduction view after a
    /// successful save cannot leave collapse/click-away permanently blocked.
    func addIntroductionSample() async -> Bool {
        guard !isPreparingIntroduction else { return false }
        isPreparingIntroduction = true
        defer { isPreparingIntroduction = false }
        guard await kit.addQuickStartPocket() else { return false }
        panelModel.restorePocketView(kit)
        finishIntroduction()
        return true
    }

    func setAppearance(_ appearance: PanelAppearance) {
        preferences.appearance = appearance
        NSApp.appearance = appearance.nsAppearance
    }

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
            EdgeLayout.panelFrame(edge: preferences.edge, size: size, centreY: panel.frame.midY, in: panelArea(on: screen), flush: preferences.fullHeight),
            display: true,
            animate: !Self.reduceMotion
        )
    }
}

extension ShellController: NSWindowDelegate {
    /// Command-Tab or clicking another app's window while editing tucks an unpinned panel.
    func windowDidResignKey(_ notification: Notification) {
        guard isOpen, !isPinned, !childIsPresented else { return }
        // AppKit can resign the parent before SwiftUI's confirmation window
        // becomes key. Decide after that transition, preserving sheets/alerts.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isOpen, !self.isPinned, !self.childIsPresented,
                  let panel = self.contentPanel, !panel.isKeyWindow,
                  panel.attachedSheet == nil, NSApp.modalWindow == nil else { return }
            if let key = NSApp.keyWindow, key !== panel { return }
            self.tuck()
        }
    }

    func windowWillBeginSheet(_ notification: Notification) {
        presentingChild = true
    }

    func windowDidEndSheet(_ notification: Notification) {
        presentingChild = archivePicker != nil || referencePicker != nil
        updateOutsideClickMonitor()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = contentPanel else { return }
        preferences.panelWidth = panel.frame.width
        if let screen = panel.screen, abs(panel.frame.height - panelArea(on: screen).height) > 4 {
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

    /// Whether the Dock is drawn along this display's bottom edge right now. Uses
    /// window positions and levels only; no window titles or permissions.
    var isBottomDockShowing: Bool {
        let reserved = visibleFrame.minY - frame.minY
        guard reserved > 8 else { return false } // Dock hidden, or on a side.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
        // The Dock strip in window-list coordinates (origin top left).
        let strip = CGRect(x: frame.minX, y: primaryHeight - visibleFrame.minY, width: frame.width, height: reserved)
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { window in
            // The Dock's desktop-level backdrop windows sit below normal windows; only a Dock
            // window above them (the visible Dock itself) counts.
            guard let layer = window[kCGWindowLayer as String] as? Int, layer > 0,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock",
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            return rect.intersects(strip)
        }
    }

    static var underPointer: NSScreen? {
        let point = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
