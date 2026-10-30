import SwiftUI

/// Menu-bar fallback: always available, even with the edge tab hidden or
/// when a full-screen app covers it.
struct MenuBarMenu: View {
    let shell: ShellController

    var body: some View {
        Button(shell.isOpen ? "Hide Nivlet" : "Show Nivlet") {
            shell.toggle(source: .menu)
        }
        Toggle("Pin Panel", isOn: Binding(get: { shell.isPinned }, set: { shell.isPinned = $0 }))

        Divider()

        PanelSettings(shell: shell)

        Divider()

        Button("Quit Nivlet") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
