import AppKit
import Observation

/// Panel color scheme. `system` follows macOS.
enum PanelAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "System"; case .light: "Light"; case .dark: "Dark" }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Device-local shell settings. Working content never lives here.
@Observable
final class ShellPreferences {
    @ObservationIgnored private let defaults: UserDefaults

    var edge: ScreenEdge {
        didSet { defaults.set(edge.rawValue, forKey: Key.edge) }
    }

    /// 0 is the lowest allowed tab position, 1 the highest.
    var tabPosition: Double {
        didSet { defaults.set(tabPosition, forKey: Key.tabPosition) }
    }

    var fullHeight: Bool {
        didSet { defaults.set(fullHeight, forKey: Key.fullHeight) }
    }

    var panelWidth: Double {
        didSet { defaults.set(panelWidth, forKey: Key.panelWidth) }
    }

    var panelHeight: Double {
        didSet { defaults.set(panelHeight, forKey: Key.panelHeight) }
    }

    /// Preferred display for the resting tab. `nil` means the primary display.
    var displayID: UInt32? {
        didSet {
            if let displayID {
                defaults.set(Int(displayID), forKey: Key.displayID)
            } else {
                defaults.removeObject(forKey: Key.displayID)
            }
        }
    }

    var showsEdgeTab: Bool {
        didSet { defaults.set(showsEdgeTab, forKey: Key.showsEdgeTab) }
    }

    var appearance: PanelAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Off until the person turns it on.
    var shortcutEnabled: Bool {
        didSet { defaults.set(shortcutEnabled, forKey: Key.shortcutEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        edge = defaults.string(forKey: Key.edge).flatMap(ScreenEdge.init(rawValue:)) ?? .right
        tabPosition = defaults.object(forKey: Key.tabPosition) as? Double ?? 0.5
        fullHeight = defaults.object(forKey: Key.fullHeight) == nil ? true : defaults.bool(forKey: Key.fullHeight)
        let storedWidth = defaults.object(forKey: Key.panelWidth) as? Double
        panelWidth = storedWidth == nil || storedWidth == EdgeLayout.previousDefaultWidth
            ? EdgeLayout.defaultPanelSize.width : storedWidth!
        panelHeight = defaults.object(forKey: Key.panelHeight) == nil
            ? EdgeLayout.defaultPanelSize.height : defaults.double(forKey: Key.panelHeight)
        displayID = (defaults.object(forKey: Key.displayID) as? Int).map { UInt32(truncatingIfNeeded: $0) }
        showsEdgeTab = defaults.object(forKey: Key.showsEdgeTab) as? Bool ?? true
        shortcutEnabled = defaults.bool(forKey: Key.shortcutEnabled)
        appearance = defaults.string(forKey: Key.appearance).flatMap(PanelAppearance.init(rawValue:)) ?? .system
    }

    func resetPanelSize() {
        panelWidth = EdgeLayout.defaultPanelSize.width
        panelHeight = EdgeLayout.defaultPanelSize.height
    }

    private enum Key {
        static let edge = "shell.edge"
        static let tabPosition = "shell.tabPosition"
        static let fullHeight = "shell.fullHeight"
        static let panelWidth = "shell.panelWidth"
        static let panelHeight = "shell.panelHeight"
        static let displayID = "shell.displayID"
        static let showsEdgeTab = "shell.showsEdgeTab"
        static let shortcutEnabled = "shell.shortcutEnabled"
        static let appearance = "shell.appearance"
    }
}
