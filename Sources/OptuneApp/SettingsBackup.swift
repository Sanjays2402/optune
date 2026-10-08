import AppKit
import Combine
import SwiftUI
import OptuneCore
import OptuneUI

/// Optional automatic backup of Optune's settings to a folder you choose (for example in
/// iCloud Drive or a Git repository). The file is stable and diff-friendly: sorted keys,
/// no timestamps, and no battery history.
@MainActor
final class SettingsBackup: ObservableObject {
    static let shared = SettingsBackup()
    static let fileName = "optune-settings.json"

    @Published private(set) var lastBackup: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var enabled: Bool
    @Published private(set) var folderPath: String?

    private let store = SettingsStore.shared
    private var pending: Task<Void, Never>?
    private var lastData: Data?

    private init() {
        enabled = SettingsStore.shared.app.backupEnabled
        folderPath = SettingsStore.shared.app.backupFolderPath
    }

    private struct Payload: Codable {
        var schema = 1
        var app: OptuneAppSettings
        var devices: [DeviceSettings]
    }

    // MARK: - Settings

    func setEnabled(_ value: Bool) {
        enabled = value
        store.updateApp { $0.backupEnabled = value }
        if value { writeNow() }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a backup folder"
        panel.message = "Optune will keep \(Self.fileName) up to date here."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        let icloud = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"
        if FileManager.default.fileExists(atPath: icloud) {
            panel.directoryURL = URL(fileURLWithPath: icloud, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderPath = url.path
        store.updateApp { $0.backupFolderPath = url.path }
        lastData = nil
        if enabled { writeNow() }
    }

    // MARK: - Writing

    /// Called after every settings save; coalesces bursts and skips unchanged content.
    func scheduleWrite() {
        guard enabled, folderPath != nil else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.writeNow()
        }
    }

    func writeNow() {
        guard let folderPath else { return }
        var devices = store.devices
        for i in devices.indices { devices[i].batteryHistory = [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Payload(app: store.app, devices: devices)) else { return }
        if data == lastData { return }
        do {
            let dir = URL(fileURLWithPath: folderPath, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent(Self.fileName), options: .atomic)
            lastData = data
            lastBackup = Date()
            lastError = nil
            OptuneLog.write(.info, "backup", "wrote settings backup")
        } catch {
            OptuneLog.write(.error, "backup", "failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    // MARK: - Import safety

    /// Shell commands bound to buttons or gestures in `devices`.
    static func shellCommands(in devices: [DeviceSettings]) -> [String] {
        var out: [String] = []
        for device in devices {
            for b in device.remapBindings ?? [] {
                if case .runShell(let cmd) = b.action { out.append(cmd) }
            }
            for g in device.gestureBindings ?? [] {
                if case .runShell(let cmd) = g.action { out.append(cmd) }
            }
        }
        return out
    }

    /// Ask before importing settings that would run shell commands. True = go ahead.
    static func confirmImport(of devices: [DeviceSettings]) -> Bool {
        let commands = shellCommands(in: devices)
        guard !commands.isEmpty else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This file will run shell commands"
        let shown = commands.prefix(5).map { "• " + String($0.prefix(80)) }.joined(separator: "\n")
        let more = commands.count > 5 ? "\n…and \(commands.count - 5) more" : ""
        alert.informativeText = "Importing will bind these commands to your buttons or gestures. They run with your user privileges whenever you press the button. Only continue if you wrote or trust this file.\n\n\(shown)\(more)"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Import Anyway")
        return alert.runModal() == .alertSecondButtonReturn
    }
}

/// General-pane section for backup settings.
struct BackupSection: View {
    @ObservedObject private var backup = SettingsBackup.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Backup")
            InsetGroup {
                InsetRow(
                    title: "Automatic backup",
                    subtitle: "Keeps a copy of your settings in a folder you choose — iCloud Drive, a Git repo, anywhere. Includes device serial numbers and any shell-command remaps."
                ) {
                    tile("externaldrive.badge.icloud", .blue)
                } trailing: {
                    Toggle("", isOn: Binding(
                        get: { backup.enabled },
                        set: { backup.setEnabled($0) }
                    ))
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    .disabled(backup.folderPath == nil)
                }
                GroupDivider()
                InsetRow(
                    title: backup.folderPath.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "No folder chosen",
                    subtitle: status
                ) {
                    tile("folder", .gray)
                } trailing: {
                    HStack(spacing: 6) {
                        Button("Choose…") { backup.chooseFolder() }
                        Button("Back up now") { backup.writeNow() }.disabled(backup.folderPath == nil)
                        Button("Restore…") { SettingsExportImport.importFromFile() }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var status: String {
        if let error = backup.lastError { return "Last backup failed: \(error)" }
        if let date = backup.lastBackup { return "Last backup \(date.formatted(.relative(presentation: .named)))" }
        return backup.folderPath == nil ? "Choose a folder to start." : "Waiting for the first backup."
    }

    private func tile(_ symbol: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
    }
}
