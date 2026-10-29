import Foundation
import Testing
@testable import Nivlet

@Suite("Shell preferences")
struct ShellPreferencesTests {
    private func defaults() -> UserDefaults {
        let name = "nivlet-prefs-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("The old default width moves to the new default; a resized width is kept")
    func widthMigration() {
        let expected = Double(EdgeLayout.defaultPanelSize.width)
        let fresh = defaults()
        #expect(ShellPreferences(defaults: fresh).panelWidth == expected)

        let oldDefault = defaults()
        oldDefault.set(Double(EdgeLayout.previousDefaultWidth), forKey: "shell.panelWidth")
        #expect(ShellPreferences(defaults: oldDefault).panelWidth == expected)

        let resized = defaults()
        resized.set(455.0, forKey: "shell.panelWidth")
        #expect(ShellPreferences(defaults: resized).panelWidth == 455)
    }

    @Test("Appearance defaults to System and persists a choice")
    func appearance() {
        let store = defaults()
        let preferences = ShellPreferences(defaults: store)
        #expect(preferences.appearance == .system)
        preferences.appearance = .light
        #expect(ShellPreferences(defaults: store).appearance == .light)
    }
}
