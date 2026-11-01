import AppKit

/// Where this copy of Nivlet runs from, and the release page that tells it about new versions.
enum InstallLocation {
    static let releasePage = URL(string: "https://nivlet.ashique.work/releases/")!

    /// Opened straight from the downloaded disk image, either at its mount point or through
    /// App Translocation. That copy disappears when the image is ejected.
    static var isRunningFromDiskImage: Bool { isDiskImage(Bundle.main.bundleURL) }

    static func isDiskImage(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
    }

    /// The release page, told which version is installed so it can say whether a newer one exists.
    /// The browser makes the request; Nivlet itself stays offline.
    static func updatePage(bundle: Bundle = .main) -> URL {
        var components = URLComponents(url: releasePage, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "installed", value: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String),
            URLQueryItem(name: "build", value: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String),
        ]
        return components.url!
    }

    /// Explains that an app run from the disk image stops working on eject. Returns true if
    /// the user chose to quit and install it properly.
    static func remindToInstall() -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Move Nivlet to Applications"
        alert.informativeText = "Nivlet is running from the disk image, so it stops working when you eject it. Quit, drag Nivlet into the Applications folder, then open it from there. Your pockets are kept."
        alert.addButton(withTitle: "Quit and Show Applications")
        alert.addButton(withTitle: "Keep Using for Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        NSWorkspace.shared.open(URL(filePath: "/Applications", directoryHint: .isDirectory))
        return true
    }
}
