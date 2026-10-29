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
            let boardName = defaults.string(forKey: "NivletVerificationPasteboard")
            let board = boardName.flatMap { $0.hasPrefix("nivlet-verification-") ? NSPasteboard(name: .init($0)) : nil } ?? .general
            return ShellController(kit: PocketLibrary(root: root), panelModel: PanelModel(pasteboard: board))
        }
        #endif
        return ShellController()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app; they exercise types directly, not the shell windows.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        shell.start()
        #if DEBUG
        // App-local appearance override for reproducible native UI captures.
        // Applied after start so it wins over the saved Appearance preference.
        if let appearance = UserDefaults.standard.string(forKey: "NivletAppearance") {
            NSApp.appearance = NSAppearance(named: appearance == "light" ? .aqua : .darkAqua)
        }
        // Verification hook: `open Nivlet.app --args -NivletOpenOnLaunch YES [-NivletTool prompts]`
        if let tool = UserDefaults.standard.string(forKey: "NivletTool").flatMap(PanelTool.init(rawValue:)) {
            shell.panelModel.tool = tool
        }
        if UserDefaults.standard.bool(forKey: "NivletOpenOnLaunch") {
            shell.open(source: .menu)
        }
        // Capture hook: `-NivletCaptureState preview|editor|actions|copy` once the library has loaded.
        if let state = UserDefaults.standard.string(forKey: "NivletCaptureState") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                let model = shell.panelModel, kit = shell.kit
                guard let id = model.resolvedSelection(kit) else { return }
                switch state {
                case "preview":
                    if let item = ShelfIndex.textItems(model.tool, kit: kit).first(where: { $0.fieldCount > 0 }) { model.open(item) }
                    else if model.tool == .references { model.inspector = .reference(id) }
                case "editor":
                    if let item = ShelfIndex.textItems(model.tool, kit: kit).first { model.edit(item, kit: kit) }
                case "actions": model.showActions(kit: kit)
                case "copy":
                    // Repeats so a recording can catch several cycles.
                    for _ in 0..<3 {
                        model.simulateCopiedForCapture(id)
                        try? await Task.sleep(for: .seconds(2.6))
                    }
                default: break
                }
            }
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
