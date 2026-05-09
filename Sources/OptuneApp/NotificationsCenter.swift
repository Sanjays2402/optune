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

    /// Manual reset hook (used when the user changes the threshold in Settings;
    /// the next poll will re-evaluate from scratch).
    func resetLowBatteryLatch() {
        firedFor.removeAll()
    }
}
