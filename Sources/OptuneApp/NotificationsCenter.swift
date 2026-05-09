import Foundation
import UserNotifications

/// Wrapper around UserNotifications that handles authorization + dedup.
/// We only fire one low-battery notification per device per drain cycle —
/// once a device crosses back above the threshold, the latch resets so the
/// next drop alerts again.
@MainActor
final class OptuneNotifications {
    static let shared = OptuneNotifications()

    /// Tracks which devices we've already alerted about during the current
    /// below-threshold window. Keyed by `pid:serial`.
    private var firedFor: Set<String> = []
    /// Connection-state cache (true = currently connected) keyed by `pid:serial`.
    private var lastConnectionState: [String: Bool] = [:]
    /// Last-known host index keyed by `pid:serial`.
    private var lastHostIndex: [String: UInt8] = [:]

    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            default:
                break
            }
        }
    }

    /// Fire a low-battery notification (if enabled) and latch on the device key
    /// so we don't spam the user every poll.
    func notifyLowBattery(
        deviceKey: String,
        deviceLabel: String,
        percent: Int,
        threshold: Int,
        enabled: Bool
    ) {
        guard enabled else { return }
        if percent > threshold {
            // Reset latch when the device leaves the danger zone.
            firedFor.remove(deviceKey)
            return
        }
        if firedFor.contains(deviceKey) { return }
        firedFor.insert(deviceKey)

        let content = UNMutableNotificationContent()
        content.title = "\(deviceLabel) battery low"
        content.body = "Currently \(percent)% — connect a USB-C cable to keep working."
        content.sound = .default
        content.categoryIdentifier = "OPTUNE_BATTERY"

        let request = UNNotificationRequest(
            identifier: "low-battery-\(deviceKey)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Fire when a device transitions from disconnected → connected (and vice
    /// versa). Suppresses noise on first sight (no notification on first scan).
    func notifyConnectionChange(
        deviceKey: String,
        deviceLabel: String,
        connected: Bool,
        enabled: Bool
    ) {
        let previous = lastConnectionState[deviceKey]
        lastConnectionState[deviceKey] = connected
        guard enabled, let previous, previous != connected else { return }

        let content = UNMutableNotificationContent()
        content.title = connected ? "\(deviceLabel) connected" : "\(deviceLabel) disconnected"
        content.body = connected
            ? "Optune is now talking to your device."
            : "Wireless link dropped — check the receiver or USB cable."
        content.sound = .default
        content.categoryIdentifier = "OPTUNE_CONNECTION"

        let request = UNNotificationRequest(
            identifier: "connection-\(deviceKey)-\(connected ? "up" : "down")",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Fire when the active host index of a multi-host device changes.
    func notifyHostSwitch(
        deviceKey: String,
        deviceLabel: String,
        hostIndex: UInt8,
        hostName: String,
        enabled: Bool
    ) {
        let previous = lastHostIndex[deviceKey]
        lastHostIndex[deviceKey] = hostIndex
        guard enabled, let previous, previous != hostIndex else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(deviceLabel) switched to \(hostName)"
        content.body = "Now paired with host \(hostIndex + 1)."
        content.sound = .default
        content.categoryIdentifier = "OPTUNE_HOST"

        let request = UNNotificationRequest(
            identifier: "host-\(deviceKey)-\(hostIndex)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Manual reset hook (used when the user changes the threshold in Settings;
    /// the next poll will re-evaluate from scratch).
    func resetLowBatteryLatch() {
        firedFor.removeAll()
    }
}
