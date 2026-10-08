import AppKit
import OptuneCore

/// A plain-text summary for bug reports. Deliberately leaves out serial numbers,
/// device nicknames, remap contents and anything else personal.
@MainActor
enum Diagnostics {
    static func report(model: DeviceModel) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var lines: [String] = [
            "Optune \(OptuneCore.Optune.version)",
            "macOS \(os)",
            "Architecture: \(architecture)",
            "Input Monitoring: \(model.permissionMissing ? "missing" : "ok")",
            "Accessibility: \(AccessibilityChecker.shared.isTrusted ? "granted" : "not granted")",
            "Devices: \(model.devices.count) (\(model.recognizedCount) recognized)",
        ]
        for device in model.devices {
            let known = DeviceRegistry.descriptor(for: device)?.modelName ?? "unrecognized"
            lines.append("  - \(device.displayName) · PID \(String(format: "0x%04X", device.productID)) · \(device.transport ?? "unknown transport") · \(known)")
        }
        lines.append("Battery: \(status(model.telemetry.battery.unavailableReason))")
        lines.append("DPI: \(status(model.telemetry.dpi.unavailableReason))")
        lines.append("SmartShift: \(status(model.telemetry.smartShift.unavailableReason))")
        lines.append("Buttons: \(status(model.telemetry.buttons.unavailableReason))")
        lines.append("")
        lines.append("--- Recent log (kept on this Mac only; redacted) ---")
        let log = OptuneLog.tail(lines: 200)
        lines.append(log.isEmpty ? "(no log entries yet)" : log)
        return lines.joined(separator: "\n")
    }

    static func copy(model: DeviceModel) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(model: model), forType: .string)
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    /// "ok", or why the feature isn't available (these are short system messages, not personal data).
    private static func status(_ unavailableReason: String?) -> String {
        unavailableReason.map { "unavailable — \($0)" } ?? "ok"
    }
}
