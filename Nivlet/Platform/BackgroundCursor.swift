import AppKit

/// Lets the panel show its pointing-hand cursor while another app stays active.
///
/// The window server ignores cursor changes from a background app, and Nivlet is
/// never the active app: a tab click deliberately leaves the AI app focused so
/// Copy then Command-V pastes there. The window-server connection property
/// `SetsCursorInBackground` lifts that restriction for this process only.
///
/// This is private API. It is resolved at runtime, so if a future macOS removes
/// it nothing breaks: the cursor simply stays the arrow until the panel is key.
/// Website (Developer ID) distribution only; the App Store would reject it.
enum BackgroundCursor {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    static func enable() {
        let process = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let connectionSymbol = dlsym(process, "_CGSDefaultConnection"),
              let setSymbol = dlsym(process, "CGSSetConnectionProperty") else { return }
        let connection = unsafeBitCast(connectionSymbol, to: DefaultConnection.self)()
        let set = unsafeBitCast(setSymbol, to: SetConnectionProperty.self)
        _ = set(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}
