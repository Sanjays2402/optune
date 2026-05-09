import ArgumentParser
import Foundation
import OptuneCore

@main
struct Optune: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "optune",
        abstract: "Configure Logitech devices on macOS — Logitech Options+ alternative.",
        version: OptuneCore.Optune.version,
        subcommands: [
            Devices.self, Doctor.self,
            Battery.self, DPICommand.self, SmartShiftCommand.self, ButtonsCommand.self,
            FirmwareCommand.self, NameCommand.self, HostCommand.self, ProfileCommand.self,
            WheelCommand.self, SpeedCommand.self, ThumbWheelCommand.self, ResetCommand.self,
            MonitorCommand.self, ExportCommand.self
        ]
    )
}

// MARK: - Common helpers

enum CLIError: Error, CustomStringConvertible {
    case noMatchingDevice
    case openFailed(String)
    case featureMissing(String)

    var description: String {
        switch self {
        case .noMatchingDevice:
            return "no matching Logitech device found"
        case .openFailed(let inner):
            return "could not open HID++ transport: \(inner)"
        case .featureMissing(let name):
            return "device does not expose \(name)"
        }
    }
}

enum CLISupport {
    /// Resolve the target device from `--pid` (hex) or fall back to MX Master 3S.
    static func resolveDevice(pid: String?) throws -> LogitechDevice {
        let raw = HIDEnumerator.logitechDevices()
        if let pid {
            let normalized = pid.replacingOccurrences(of: "0x", with: "")
            guard let value = Int(normalized, radix: 16) else {
                throw ValidationError("Invalid --pid '\(pid)' (expected hex like 0xB034).")
            }
            if let match = raw.first(where: { $0.productID == value && $0.speaksHIDPP }) {
                return match
            }
            if let match = raw.first(where: { $0.productID == value }) {
                return match
            }
        }
        if let match = raw.first(where: { $0.isMXMaster3S && $0.speaksHIDPP }) {
            return match
        }
        if let match = raw.first(where: { DeviceRegistry.descriptor(for: $0) != nil && $0.speaksHIDPP }) {
            return match
        }
        if let match = raw.first(where: { $0.speaksHIDPP }) {
            return match
        }
        throw CLIError.noMatchingDevice
    }

    /// Open a transport with a friendly TCC hint on failure.
    static func openTransport(for device: LogitechDevice) throws -> HIDPPTransport {
        do {
            return try HIDPPTransport(matching: device)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            FileHandle.standardError.write(Data("hint: macOS requires Input Monitoring permission for HID++ access.\n".utf8))
            FileHandle.standardError.write(Data("      System Settings → Privacy & Security → Input Monitoring → add `optune`.\n".utf8))
            throw CLIError.openFailed("\(error)")
        }
    }

    static func writeJSON(_ obj: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        if let s = String(data: data, encoding: .utf8) { print(s) }
    }
}

// MARK: - battery

struct Battery: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read battery state from a connected Logitech device via HID++."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON instead of a human-readable line.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: UnifiedBatteryFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("UnifiedBattery (0x1004)") }

        let status = try await UnifiedBatteryFeature.getStatus(
            on: transport,
            featureIndex: lookup.featureIndex
        )

        if json {
            try CLISupport.writeJSON([
                "device": device.displayName,
                "productId": String(format: "0x%04X", device.productID),
                "percent": status.percent,
                "chargingState": "\(status.chargingState)",
                "externalPower": status.externalPower,
                "featureIndex": String(format: "0x%02X", lookup.featureIndex),
                "featureVersion": lookup.featureVersion
            ])
            return
        }

        let bar = batteryBar(percent: Int(status.percent))
        print("\(device.displayName)  \(bar)  \(status.percent)% — \(status.chargingState)\(status.externalPower ? "  ⚡" : "")")
    }

    private func batteryBar(percent: Int) -> String {
        let total = 10
        let filled = max(0, min(total, percent / 10))
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: total - filled) + "]"
    }
}

// MARK: - dpi

struct DPICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dpi",
        abstract: "Read or set the cursor sensitivity (DPI) on a connected Logitech device."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Option(name: .shortAndLong, help: "Set DPI to this value (e.g. 4000). Omit to read current.")
    var value: Int?

    @Flag(name: .shortAndLong, help: "Output JSON instead of a human-readable summary.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let snapshot = try await AdjustableDPIFeature.snapshot(on: transport)

        if let target = value {
            let descriptor = DeviceRegistry.descriptor(for: device)
            let clamped = DeviceRegistry.clampDPI(target, for: descriptor)
            let lookup = try await RootFeature.getFeature(on: transport, featureID: AdjustableDPIFeature.id)
            let applied = try await AdjustableDPIFeature.setDPI(
                on: transport,
                featureIndex: lookup.featureIndex,
                dpi: clamped
            )
            if json {
                try CLISupport.writeJSON([
                    "device": device.displayName,
                    "productId": String(format: "0x%04X", device.productID),
                    "previousDPI": snapshot.currentDPI,
                    "appliedDPI": applied,
                    "requestedDPI": target,
                    "clampedDPI": clamped
                ])
            } else {
                print("\(device.displayName)  DPI: \(snapshot.currentDPI) → \(applied)")
                if applied != target {
                    print("  (clamped to device range \(snapshot.range.min)…\(snapshot.range.max))")
                }
            }
            return
        }

        if json {
            var out: [String: Any] = [
                "device": device.displayName,
                "productId": String(format: "0x%04X", device.productID),
                "currentDPI": snapshot.currentDPI,
                "min": snapshot.range.min,
                "max": snapshot.range.max
            ]
            if let def = snapshot.defaultDPI { out["defaultDPI"] = def }
            if let step = snapshot.range.step { out["step"] = step }
            if !snapshot.range.presets.isEmpty { out["presets"] = snapshot.range.presets }
            try CLISupport.writeJSON(out)
            return
        }

        print("\(device.displayName)")
        print("  Current DPI:  \(snapshot.currentDPI)")
        if let def = snapshot.defaultDPI { print("  Default DPI:  \(def)") }
        print("  Range:        \(snapshot.range.min) … \(snapshot.range.max)\(snapshot.range.step.map { " (step \($0))" } ?? "")")
        if !snapshot.range.presets.isEmpty {
            print("  Presets:      \(snapshot.range.presets.map(String.init).joined(separator: ", "))")
        }
    }
}

// MARK: - smartshift

struct SmartShiftCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smartshift",
        abstract: "Read or set SmartShift (auto-engage scroll wheel freespin) configuration."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Flag(name: .long, help: "Enable SmartShift with the threshold from --threshold.")
    var enable: Bool = false

    @Flag(name: .long, help: "Disable SmartShift (wheel stays in fixed ratchet).")
    var disable: Bool = false

    @Option(name: .shortAndLong, help: "Sensitivity threshold 1...50 (lower = more sensitive). Default 25.")
    var threshold: UInt8?

    @Flag(name: .shortAndLong, help: "Output JSON instead of human-readable.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: SmartShiftFeature.id)
        guard lookup.isPresent else {
            throw CLIError.featureMissing("SmartShift Enhanced (0x2111)")
        }

        if enable || disable {
            let target = threshold ?? 25
            let status = try await SmartShiftFeature.setStatus(
                on: transport,
                featureIndex: lookup.featureIndex,
                mode: .ratchet,
                enabled: enable,
                threshold: target
            )
            print("SmartShift \(status.smartShiftEnabled ? "ON" : "OFF") · \(status.thresholdLabel)")
            return
        }

        let status = try await SmartShiftFeature.getStatus(
            on: transport,
            featureIndex: lookup.featureIndex
        )

        if json {
            try CLISupport.writeJSON([
                "device": device.displayName,
                "productId": String(format: "0x%04X", device.productID),
                "mode": status.mode.description,
                "smartShiftEnabled": status.smartShiftEnabled,
                "autoDisengage": status.autoDisengage,
                "defaultThreshold": status.defaultThreshold
            ])
            return
        }

        print("\(device.displayName)")
        print("  Wheel mode:          \(status.mode)")
        print("  SmartShift:          \(status.smartShiftEnabled ? "ON" : "OFF")  · \(status.thresholdLabel)")
        print("  Default threshold:   \(status.defaultThreshold)")
    }
}

// MARK: - buttons

struct ButtonsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "buttons",
        abstract: "Enumerate the device's reprogrammable buttons (HID++ feature 0x1B04)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON instead of a human-readable table.")
    var json: Bool = false

    @Flag(name: .long, help: "Include non-reprogrammable controls in the output.")
    var includeFixed: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let controls = try await ReprogControlsV4Feature.snapshot(on: transport)
        let filtered = includeFixed ? controls : controls.filter(\.isReprogrammable)

        if json {
            let payload: [[String: Any]] = filtered.map { control in
                [
                    "index": control.index,
                    "cid": String(format: "0x%04X", control.cid),
                    "name": control.friendlyName,
                    "taskId": String(format: "0x%04X", control.taskID),
                    "flags": String(format: "0x%02X", control.flags),
                    "reprogrammable": control.isReprogrammable,
                    "mouseButton": control.isMouseButton,
                    "fnKey": control.isFKey,
                    "virtual": control.isVirtual,
                    "position": control.position
                ]
            }
            try CLISupport.writeJSON(payload)
            return
        }

        if filtered.isEmpty {
            print("\(device.displayName) does not expose ReprogControlsV4 (0x1B04).")
            print("Tip: try --include-fixed if your firmware only reports fixed buttons.")
            return
        }

        print("\(device.displayName) — \(filtered.count) control\(filtered.count == 1 ? "" : "s")")
        print("")
        print("  IDX  CID     NAME                         FLAGS  POS")
        print("  ───  ──────  ───────────────────────────  ─────  ───")
        for c in filtered {
            let name = c.friendlyName.padding(toLength: 27, withPad: " ", startingAt: 0)
            print(String(format: "  %3d  0x%04X  \(name)  0x%02X   %3d", c.index, c.cid, c.flags, c.position))
        }
    }
}

// MARK: - devices

struct Devices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List attached Logitech HID devices."
    )

    @Flag(name: .shortAndLong, help: "Output JSON instead of a human-readable table.")
    var json: Bool = false

    @Flag(name: .long, help: "Show every Logitech HID interface, not just HID++ endpoints.")
    var all: Bool = false

    func run() async throws {
        let raw = HIDEnumerator.logitechDevices()
        let devices = all ? raw : raw.filter { $0.speaksHIDPP || DeviceRegistry.descriptor(for: $0) != nil }

        if json {
            let payload = devices.map { device -> [String: Any] in
                var dict: [String: Any] = [
                    "productId": String(format: "0x%04X", device.productID),
                    "productName": device.displayName,
                    "manufacturer": device.manufacturer,
                    "transport": device.transport ?? "",
                    "usagePage": String(format: "0x%04X", device.usagePage),
                    "usage": String(format: "0x%04X", device.usage),
                    "speaksHIDPP": device.speaksHIDPP
                ]
                if let serial = device.serialNumber { dict["serial"] = serial }
                if let descriptor = DeviceRegistry.descriptor(for: device) {
                    dict["model"] = descriptor.modelName
                    dict["codename"] = descriptor.codename
                    dict["dpiMax"] = descriptor.dpiMax
                }
                return dict
            }
            try CLISupport.writeJSON(payload)
            return
        }

        if devices.isEmpty {
            print("No Logitech HID devices found.")
            print("Tip: pair via Bluetooth or plug in a Bolt/Unifying receiver, then re-run.")
            return
        }

        print("Found \(devices.count) Logitech device\(devices.count == 1 ? "" : "s"):\n")
        for device in devices {
            let pid = String(format: "0x%04X", device.productID)
            let descriptor = DeviceRegistry.descriptor(for: device)
            let badge = descriptor != nil
                ? "✅ supported"
                : (device.speaksHIDPP ? "🟡 HID++ (no descriptor)" : "⚪ generic HID")
            print("  • \(device.displayName)  [\(pid)]  \(badge)")
            print("      transport: \(device.transport ?? "unknown")  usage: \(String(format: "0x%04X/0x%04X", device.usagePage, device.usage))")
            if let descriptor {
                print("      model:     \(descriptor.modelName) (\(descriptor.codename))   dpi max: \(descriptor.dpiMax)")
            }
            if let serial = device.serialNumber, !serial.isEmpty {
                print("      serial:    \(serial)")
            }
        }
        print("")
        print("Pass --json for machine-readable output, or --all to see every interface.")
    }
}

// MARK: - doctor

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diagnostic checks for Optune readiness."
    )

    func run() async throws {
        print("Optune \(OptuneCore.Optune.version) — readiness check")
        print("──────────────────────────────────────────────")

        let devices = HIDEnumerator.logitechDevices()
        if devices.isEmpty {
            print("✗ No Logitech HID devices visible. Check pairing/receiver/Bluetooth.")
        } else {
            print("✓ \(devices.count) Logitech HID interface\(devices.count == 1 ? "" : "s") visible")
        }

        let recognized = devices.compactMap { DeviceRegistry.descriptor(for: $0) }
        if recognized.isEmpty {
            print("✗ No devices matched a built-in descriptor (\(DeviceRegistry.all.count) descriptors registered).")
        } else {
            for descriptor in Set(recognized) {
                print("✓ Recognized: \(descriptor.modelName)")
            }
        }

        let hidppCapable = devices.filter {
            DeviceRegistry.descriptor(for: $0) != nil || $0.speaksHIDPP
        }
        if hidppCapable.isEmpty {
            print("✗ No HID++-capable interface visible.")
        } else {
            print("✓ \(hidppCapable.count) HID++-capable interface\(hidppCapable.count == 1 ? "" : "s") detected")
        }

        if let target = hidppCapable.first(where: { $0.isMXMaster3S }) ?? hidppCapable.first {
            do {
                let transport = try HIDPPTransport(matching: target)
                transport.close()
                print("✓ HID++ transport opens on \(target.displayName)")

                let probe = try HIDPPTransport(matching: target)
                defer { probe.close() }
                do {
                    _ = try await RootFeature.getFeature(on: probe, featureID: 0x0000)
                    print("✓ HID++ round-trip succeeds — Input Monitoring is granted")

                    // Probe individual features so 'optune doctor' reports concrete capabilities.
                    let battery = (try? await RootFeature.getFeature(on: probe, featureID: UnifiedBatteryFeature.id))?.isPresent ?? false
                    let dpi = (try? await RootFeature.getFeature(on: probe, featureID: AdjustableDPIFeature.id))?.isPresent ?? false
                    let smart = (try? await RootFeature.getFeature(on: probe, featureID: SmartShiftFeature.id))?.isPresent ?? false
                    let buttons = (try? await RootFeature.getFeature(on: probe, featureID: ReprogControlsV4Feature.id))?.isPresent ?? false
                    print("  Capabilities:")
                    print("    \(battery ? "✓" : "✗") UnifiedBattery   (0x1004)")
                    print("    \(dpi ? "✓" : "✗") AdjustableDPI    (0x2201)")
                    print("    \(smart ? "✓" : "✗") SmartShift       (0x2111)")
                    print("    \(buttons ? "✓" : "✗") ReprogControlsV4 (0x1B04)")
                } catch HIDPPError.timeout {
                    print("✗ HID++ request timed out — likely Input Monitoring permission denied.")
                    print("  System Settings → Privacy & Security → Input Monitoring → toggle ON for this binary.")
                } catch {
                    print("⚠ HID++ probe error: \(error)")
                }
            } catch {
                print("✗ Cannot open HID++ transport: \(error)")
                print("  System Settings → Privacy & Security → Input Monitoring → add `optune`.")
            }
        }

        print("")
        print("Project: \(OptuneCore.Optune.projectURL)")
    }
}
