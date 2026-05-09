import Foundation
import AppKit
import Combine
import OptuneCore

/// Per-app profile entry. When the foreground app's bundle ID matches `bundleIDs`,
/// the listed knobs (DPI, pointer-speed, SmartShift, wheel) get applied.
struct AppProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Empty array = "default" (catch-all when no bundle matches).
    var bundleIDs: [String]
    var dpi: Int?
    var pointerSpeed: Double?
    var smartShiftEnabled: Bool?
    var smartShiftThreshold: UInt8?
    var wheelInverted: Bool?
    var wheelRatchet: Bool?
}

/// Watches frontmost-app changes, picks the matching profile, and asks the
/// `DeviceModel` to apply the differential. Profiles persist in `SettingsStore`.
@MainActor
final class AppProfileManager: ObservableObject {
    @Published var profiles: [AppProfile] = []
    @Published private(set) var activeProfileID: UUID?
    @Published var enabled: Bool = true

    weak var deviceModel: DeviceModel?
    private let store: SettingsStore
    private var observer: NSObjectProtocol?
    private var lastAppliedBundle: String?

    init(store: SettingsStore = .shared) {
        self.store = store
        self.profiles = store.app.appProfiles
        self.enabled = store.app.appProfilesEnabled
        installObserver()
    }

    // No deinit — Swift 6 can't access non-Sendable `observer` from
    // a nonisolated deinit, and `AppProfileManager` is owned by the
    // app for its full lifetime so cleanup isn't required.

    private func installObserver() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier else { return }
            Task { @MainActor in
                self?.applyForBundleIfNeeded(bid)
            }
        }
        // Also fire once now for the current frontmost app.
        if let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            applyForBundleIfNeeded(bid)
        }
    }

    func applyForBundleIfNeeded(_ bundleID: String) {
        guard enabled else { return }
        guard bundleID != lastAppliedBundle else { return }
        guard let profile = matchProfile(for: bundleID) else {
            activeProfileID = nil
            return
        }
        lastAppliedBundle = bundleID
        activeProfileID = profile.id
        apply(profile: profile)
    }

    private func matchProfile(for bundleID: String) -> AppProfile? {
        if let exact = profiles.first(where: { $0.bundleIDs.contains(bundleID) }) {
            return exact
        }
        // Default profile = entry with empty bundleIDs list.
        return profiles.first(where: { $0.bundleIDs.isEmpty })
    }

    private func apply(profile: AppProfile) {
        guard let model = deviceModel else { return }
        if let dpi = profile.dpi {
            model.applyDPI(dpi)
        }
        if let speed = profile.pointerSpeed {
            model.setPointerSpeed(speed)
        }
        if let enabled = profile.smartShiftEnabled {
            model.setSmartShiftEnabled(enabled, threshold: profile.smartShiftThreshold)
        }
        if let inverted = profile.wheelInverted {
            model.setWheelInverted(inverted)
        }
        if let ratchet = profile.wheelRatchet {
            model.setWheelRatchet(ratchet)
        }
    }

    // MARK: - CRUD

    func upsert(_ profile: AppProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        persist()
    }

    func remove(_ profile: AppProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        store.updateApp { $0.appProfilesEnabled = value }
        if value {
            // Re-fire for current foreground app.
            lastAppliedBundle = nil
            if let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                applyForBundleIfNeeded(bid)
            }
        }
    }

    private func persist() {
        store.updateApp { $0.appProfiles = profiles }
    }
}

/// Helper for the picker: list installed macOS apps with names + icons.
struct InstalledApp: Identifiable, Hashable {
    let id: String     // bundle ID
    let name: String
    let iconURL: URL?

    static func discover(limit: Int = 200) -> [InstalledApp] {
        let urls: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Applications")
        ]
        var results: [InstalledApp] = []
        let fm = FileManager.default
        for dir in urls {
            guard let listing = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for url in listing where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bid = bundle.bundleIdentifier else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                results.append(InstalledApp(id: bid, name: name, iconURL: url))
                if results.count >= limit { break }
            }
        }
        return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
