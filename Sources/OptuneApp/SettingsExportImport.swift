import Foundation
import AppKit

/// Settings export/import. Dumps `~/Library/Application Support/Optune/settings.json`
/// to a user-chosen location, or replaces the current store with one read from
/// disk.
@MainActor
enum SettingsExportImport {

    /// Show the user a save panel and write the current settings to it.
    static func exportToFile() {
        let panel = NSSavePanel()
        panel.title = "Export Optune Settings"
        panel.nameFieldStringValue = "optune-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let store = SettingsStore.shared
        let payload = ExportPayload(app: store.app, devices: store.devices, exportedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Show an open panel and import settings from JSON.
    static func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Optune Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(ExportPayload.self, from: data) else {
            // Fall back to the legacy Store schema.
            if let legacy = try? decoder.decode(LegacyStorePayload.self, from: data) {
                SettingsStore.shared.replaceState(app: legacy.app, devices: legacy.devices)
            }
            return
        }
        SettingsStore.shared.replaceState(app: payload.app, devices: payload.devices)
    }

    private struct ExportPayload: Codable {
        var app: OptuneAppSettings
        var devices: [DeviceSettings]
        var exportedAt: Date
    }

    private struct LegacyStorePayload: Codable {
        var app: OptuneAppSettings
        var devices: [DeviceSettings]
    }
}

extension SettingsStore {
    /// Replace the in-memory state and persist. Used by import.
    func replaceState(app: OptuneAppSettings, devices: [DeviceSettings]) {
        self.app = app
        self.devices = devices
        // Trigger a save by mutating through the public path.
        updateApp { _ in }
    }
}
