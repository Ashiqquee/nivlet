import AppKit
import Carbon.HIToolbox

/// The one global shortcut Nivlet offers in Phase 1: Shift-Command-Space.
/// Uses Carbon hot keys, which need no Accessibility or Input Monitoring permission.
final class GlobalHotKey {
    enum RegistrationError: Error, Equatable {
        /// macOS already reserves the combination (System Settings ▸ Keyboard Shortcuts).
        case reservedBySystem
        /// Another app registered the same combination first.
        case inUseByAnotherApp
        case failed(OSStatus)

        var message: String {
            switch self {
            case .reservedBySystem: "⇧⌘Space is already a macOS keyboard shortcut."
            case .inUseByAnotherApp: "Another app is already using ⇧⌘Space."
            case .failed(let status): "The shortcut couldn't be turned on (error \(status))."
            }
        }
    }

    static let displayName = "⇧⌘Space"
    static let keyCode = UInt32(kVK_Space)
    static let modifiers = UInt32(cmdKey | shiftKey)

    private let onPress: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    var isRegistered: Bool { hotKeyRef != nil }

    func register() throws(RegistrationError) {
        guard hotKeyRef == nil else { return }
        if Self.isReservedBySystem(keyCode: Self.keyCode, carbonModifiers: Self.modifiers) {
            throw .reservedBySystem
        }
        try installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(Self.keyCode, Self.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        switch status {
        case noErr: hotKeyRef = ref
        case OSStatus(eventHotKeyExistsErr): throw .inUseByAnotherApp
        default: throw .failed(status)
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    fileprivate func fire() {
        onPress()
    }

    private func installHandlerIfNeeded() throws(RegistrationError) {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, context, &handlerRef)
        guard status == noErr else { throw .failed(status) }
    }

    /// Checks the system's own symbolic hot keys (Spotlight, input sources and so on).
    static func isReservedBySystem(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let entries = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return false }
        return entries.contains { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int else { return false }
            let relevant = UInt32(cmdKey | shiftKey | optionKey | controlKey)
            return UInt32(code) == keyCode && UInt32(mods) & relevant == carbonModifiers & relevant
        }
    }

    /// "NVLT"
    private static let signature: OSType = 0x4E564C54
}

/// Carbon delivers application-target hot key events on the main thread.
private nonisolated func hotKeyEventHandler(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        hotKey.fire()
    }
    return noErr
}
