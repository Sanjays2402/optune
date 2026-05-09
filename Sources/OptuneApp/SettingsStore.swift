import Foundation
import OptuneCore

/// Persistent per-device preferences that should survive app relaunch.
/// Stored as JSON at `~/Library/Application Support/Optune/devices.json`.
struct DeviceSettings: Codable, Equatable {
    var productID: Int
    var serialNumber: String?
    /// User's preferred DPI — applied automatically on first reconnect after a wake/relaunch.
    var preferredDPI: Int?
    /// Re-arm SmartShift on connect with this configuration.
    var smartShiftEnabled: Bool?
    var smartShiftThreshold: UInt8?
    /// Pointer-speed multiplier (0x2205 8.8 fixed point).
    var pointerSpeedMultiplier: Double?
    /// Whether to invert the wheel.
    var wheelInverted: Bool?
    /// Whether to engage ratchet on connect (only meaningful for HiResWheel-capable devices).
    var wheelRatchet: Bool?
    /// Whether to divert the side thumb wheel via 0x2150 (silences/captures it on macOS).
    var thumbWheelDiverted: Bool?
    /// Whether to invert the side thumb wheel via 0x2150.
    var thumbWheelInverted: Bool?
    /// User's nickname for this device (read from 0x0007 if none stored).
    var nickname: String?
    /// Last-seen battery percentage; we keep a small ring buffer for the sparkline.
    var batteryHistory: [BatterySample]

    init(productID: Int, serialNumber: String? = nil) {
        self.productID = productID
        self.serialNumber = serialNumber
        self.batteryHistory = []
    }
}

struct BatterySample: Codable, Equatable {
    let timestamp: Date
    let percent: Int
    let charging: Bool
}

/// Top-level app preferences (notifications, login item).
struct OptuneAppSettings: Codable, Equatable {
    /// Notify when any device drops below this %. Default 20.
    var lowBatteryThreshold: Int = 20
    /// Whether the user opted into low-battery notifications.
    var lowBatteryNotificationsEnabled: Bool = true
    /// Notify when a device connects/disconnects.
    var connectionNotificationsEnabled: Bool = true
    /// Notify when the host changes (multi-host devices).
    var hostSwitchNotificationsEnabled: Bool = true
    /// Whether Optune launches at login (mirror of SMAppService state).
    var launchAtLogin: Bool = false
    /// Whether to auto-apply persisted DPI/SmartShift on reconnect.
    var autoApplyOnReconnect: Bool = true
    /// Whether per-app profiles are active.
    var appProfilesEnabled: Bool = true
    /// User-configured per-app profile list.
    var appProfiles: [AppProfile] = []
    /// Auto-update check toggle (Sparkle uses this).
    var autoUpdateEnabled: Bool = true
    /// Whether the welcome window has been completed once.
    var welcomeCompleted: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case lowBatteryThreshold, lowBatteryNotificationsEnabled
        case connectionNotificationsEnabled, hostSwitchNotificationsEnabled
        case launchAtLogin, autoApplyOnReconnect
        case appProfilesEnabled, appProfiles, autoUpdateEnabled, welcomeCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lowBatteryThreshold              = (try? c.decodeIfPresent(Int.self,    forKey: .lowBatteryThreshold))              ?? 20
        lowBatteryNotificationsEnabled   = (try? c.decodeIfPresent(Bool.self,   forKey: .lowBatteryNotificationsEnabled))   ?? true
        connectionNotificationsEnabled   = (try? c.decodeIfPresent(Bool.self,   forKey: .connectionNotificationsEnabled))   ?? true
        hostSwitchNotificationsEnabled   = (try? c.decodeIfPresent(Bool.self,   forKey: .hostSwitchNotificationsEnabled))   ?? true
        launchAtLogin                    = (try? c.decodeIfPresent(Bool.self,   forKey: .launchAtLogin))                    ?? false
        autoApplyOnReconnect             = (try? c.decodeIfPresent(Bool.self,   forKey: .autoApplyOnReconnect))             ?? true
        appProfilesEnabled               = (try? c.decodeIfPresent(Bool.self,   forKey: .appProfilesEnabled))               ?? true
        appProfiles                      = (try? c.decodeIfPresent([AppProfile].self, forKey: .appProfiles))                ?? []
        autoUpdateEnabled                = (try? c.decodeIfPresent(Bool.self,   forKey: .autoUpdateEnabled))                ?? true
        welcomeCompleted                 = (try? c.decodeIfPresent(Bool.self,   forKey: .welcomeCompleted))                 ?? false
    }
}

/// Loads and saves Optune persistent state. Single source of truth — `DeviceModel`
/// wraps a `SettingsStore` and observes its writes to keep behaviour consistent
/// across app, CLI, and showcase invocations.
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private let storeURL: URL
    internal var app: OptuneAppSettings
    internal var devices: [DeviceSettings]

    init() {
        let fm = FileManager.default
        let support = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("Optune", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: storeURL),
           let payload = try? JSONDecoder().decode(StorePayload.self, from: data) {
            self.app = payload.app
            self.devices = payload.devices
        } else {
            self.app = OptuneAppSettings()
            self.devices = []
        }
    }

    private struct StorePayload: Codable {
        var app: OptuneAppSettings
        var devices: [DeviceSettings]
    }

    private func save() {
        let payload = StorePayload(app: app, devices: devices)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    func updateApp(_ mutate: (inout OptuneAppSettings) -> Void) {
        mutate(&app)
        save()
    }

    func settings(for device: LogitechDevice) -> DeviceSettings {
        if let existing = devices.first(where: { matches($0, device: device) }) {
            return existing
        }
        return DeviceSettings(productID: device.productID, serialNumber: device.serialNumber)
    }

    func update(for device: LogitechDevice, _ mutate: (inout DeviceSettings) -> Void) {
        var current = settings(for: device)
        mutate(&current)
        if let idx = devices.firstIndex(where: { matches($0, device: device) }) {
            devices[idx] = current
        } else {
            devices.append(current)
        }
        save()
    }

    /// Returns the persisted battery samples for this device (newest last).
    func batteryHistory(for device: LogitechDevice) -> [BatterySample] {
        settings(for: device).batteryHistory
    }

    /// Append a battery reading to this device's ring buffer (60 samples ≈ 1 hour
    /// at 60 s polling). Auto-trims the buffer to the most recent 60.
    func recordBattery(percent: Int, charging: Bool, for device: LogitechDevice) {
        update(for: device) { settings in
            settings.batteryHistory.append(BatterySample(
                timestamp: Date(),
                percent: percent,
                charging: charging
            ))
            if settings.batteryHistory.count > 60 {
                settings.batteryHistory.removeFirst(settings.batteryHistory.count - 60)
            }
        }
    }

    private func matches(_ stored: DeviceSettings, device: LogitechDevice) -> Bool {
        if let s1 = stored.serialNumber, let s2 = device.serialNumber, !s1.isEmpty, !s2.isEmpty {
            return s1 == s2 && stored.productID == device.productID
        }
        return stored.productID == device.productID
    }
}
