import AppKit
import Foundation
import ServiceManagement

/// SMAppService wrapper for "Launch at login". macOS 13+ exclusively — we
/// register the main app bundle as a login item, fall back to a no-op if the
/// app is running unbundled (e.g. via `swift run OptuneApp`) since SMAppService
/// requires a real bundle ID.
enum LoginItem {
    static var isAvailable: Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return true
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // Surfaced via the toggle remaining in its previous state — log to stderr.
            FileHandle.standardError.write(Data("LoginItem error: \(error)\n".utf8))
        }
    }
}

/// Listens for system sleep/wake notifications and pings a closure on wake.
/// Subscribers refresh telemetry so the menu bar shows fresh data the moment
/// the user lifts their lid.
final class SleepObserver: @unchecked Sendable {
    private var observers: [NSObjectProtocol] = []
    private let onWake: @Sendable () -> Void

    init(onWake: @escaping @Sendable () -> Void) {
        self.onWake = onWake
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [onWake] _ in
            onWake()
        })
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for obs in observers {
            center.removeObserver(obs)
        }
    }
}
