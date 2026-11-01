import AppKit
import Observation
import ServiceManagement

/// Open at Login, backed by the system login-item list so the user can also change it in
/// System Settings › General › Login Items. Off until the user turns it on.
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    private(set) var message: String?

    init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = "Couldn’t change Open at Login. Try again in System Settings › General › Login Items."
        }
        if SMAppService.mainApp.status == .requiresApproval {
            message = "Allow Nivlet in System Settings › General › Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
