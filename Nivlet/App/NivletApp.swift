import SwiftUI

@main
struct NivletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Nivlet", systemImage: "sidebar.right") {
            MenuBarMenu(shell: appDelegate.shell)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let shell: ShellController = {
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "NivletPreview") { return ShellController(kit: PocketLibrary(preview: true)) }
        if let name = defaults.string(forKey: "NivletVerificationLibrary") ?? defaults.string(forKey: "NivletDevelopmentLibrary"),
           name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
            // Remember the active local development pocket across ordinary
            // relaunches; no working content is moved or overwritten.
            defaults.set(name, forKey: "NivletDevelopmentLibrary")
            let root = URL.applicationSupportDirectory.appending(path: "ashique.nivlet.Nivlet/verification-\(name)")
            return ShellController(kit: PocketLibrary(root: root))
        }
        #endif
        return ShellController()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app; they exercise types directly, not the shell windows.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        #if DEBUG
        // App-local appearance override for reproducible native UI captures.
        if let appearance = UserDefaults.standard.string(forKey: "NivletAppearance") {
            NSApp.appearance = NSAppearance(named: appearance == "light" ? .aqua : .darkAqua)
        }
        #endif
        shell.start()
        #if DEBUG
        // Verification hook: `open Nivlet.app --args -NivletOpenOnLaunch YES [-NivletTool prompts]`
        if let tool = UserDefaults.standard.string(forKey: "NivletTool").flatMap(PanelTool.init(rawValue:)) {
            shell.panelModel.tool = tool
        }
        if UserDefaults.standard.bool(forKey: "NivletOpenOnLaunch") {
            shell.open(source: .menu)
        }
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shell.panelModel.draft?.hasChanges == true {
            let alert = NSAlert()
            alert.messageText = "You have an unsaved draft"
            alert.informativeText = "Keep editing to save it, or discard the draft before quitting."
            alert.addButton(withTitle: "Keep editing")
            alert.addButton(withTitle: "Discard and quit")
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
            shell.panelModel.discardDraft()
        }
        guard shell.kit.hasUnsavedChanges else { return .terminateNow }
        Task {
            let saved = await shell.kit.flush()
            if !saved {
                let alert = NSAlert()
                alert.messageText = "Couldn't save changes"
                alert.informativeText = "Nivlet will stay open so you can retry or copy your changes."
                alert.addButton(withTitle: "Keep Nivlet open")
                alert.runModal()
            }
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }

    /// Opening Nivlet again (Spotlight, Finder) shows the panel. This fallback still
    /// works when a crowded or notched menu bar hides the menu-bar item.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shell.open(source: .menu)
        return false
    }
}
