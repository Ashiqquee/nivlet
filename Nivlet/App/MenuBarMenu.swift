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

        Picker("Edge", selection: Binding(get: { shell.preferences.edge }, set: { shell.setEdge($0) })) {
            ForEach(ScreenEdge.allCases) { edge in
                Text(edge.title).tag(edge)
            }
        }
        Picker("Display", selection: Binding(get: { shell.preferences.displayID }, set: { shell.setDisplay($0) })) {
            // Reading the revision rebuilds this list when displays change.
            let _ = shell.screensRevision
            Text("Primary Display").tag(UInt32?.none)
            ForEach(NSScreen.screens, id: \.displayID) { screen in
                Text(screen.localizedName).tag(screen.displayID)
            }
        }
        Toggle("Show Edge Tab", isOn: Binding(get: { shell.preferences.showsEdgeTab }, set: { shell.setShowsEdgeTab($0) }))
        Toggle(
            "Global Shortcut \(GlobalHotKey.displayName)",
            isOn: Binding(get: { shell.preferences.shortcutEnabled }, set: { shell.setShortcutEnabled($0) })
        )
        if let error = shell.shortcutError {
            Text(error)
        }
        Toggle("Full Height", isOn: Binding(get: { shell.preferences.fullHeight }, set: shell.setFullHeight))
        Button("Reset Panel Size") {
            shell.resetPanelSize()
        }

        Divider()

        Button("Quit Nivlet") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
