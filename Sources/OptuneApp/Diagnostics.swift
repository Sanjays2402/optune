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
        lines.append("Battery: \(describe(model.telemetry.battery))")
        lines.append("DPI: \(describe(model.telemetry.dpi))")
        lines.append("SmartShift: \(describe(model.telemetry.smartShift))")
        lines.append("Buttons: \(describe(model.telemetry.buttons))")
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

    private static func describe<T>(_ value: T) -> String {
        // Enum case name only (e.g. "ok", "unavailable") — payloads can carry device data.
        let text = String(describing: value)
        return String(text.prefix { $0 != "(" })
    }
}
