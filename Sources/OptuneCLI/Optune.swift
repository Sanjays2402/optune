import ArgumentParser
import Foundation
import OptuneCore

@main
struct Optune: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "optune",
        abstract: "Configure Logitech devices on macOS — Logitech Options+ alternative.",
        version: OptuneCore.Optune.version,
        subcommands: [Devices.self, Doctor.self, Battery.self]
    )
}

struct Battery: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read battery state from a connected Logitech device via HID++."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034). Defaults to MX Master 3S.")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON instead of a human-readable line.")
    var json: Bool = false

    @Option(name: .long, help: "Per-request timeout in seconds.")
    var timeout: Double = 1.5

    func run() async throws {
        let target = HIDEnumerator.logitechDevices().first { device in
            if let pid {
                let parsed = Int(pid.replacingOccurrences(of: "0x", with: ""), radix: 16)
                return parsed.map { $0 == device.productID } ?? false
            }
            return device.isMXMaster3S && device.speaksHIDPP
        } ?? HIDEnumerator.logitechDevices().first { $0.isMXMaster3S }

        guard let device = target else {
            FileHandle.standardError.write(Data("error: no matching Logitech device found\n".utf8))
            throw ExitCode.failure
        }

        let transport: HIDPPTransport
        do {
            transport = try HIDPPTransport(matching: device)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            FileHandle.standardError.write(Data("hint: macOS requires Input Monitoring permission for HID++ access.\n".utf8))
            FileHandle.standardError.write(Data("      System Settings → Privacy & Security → Input Monitoring → add `optune`.\n".utf8))
            throw ExitCode.failure
        }
        defer { transport.close() }

        // Step 1: discover feature index for UnifiedBattery (0x1004) via Root.
        let lookup = try await RootFeature.getFeature(on: transport, featureID: UnifiedBatteryFeature.id)
        guard lookup.isPresent else {
            FileHandle.standardError.write(Data("error: device does not expose Feature 0x1004 (UnifiedBattery)\n".utf8))
            throw ExitCode.failure
        }

        // Step 2: query battery status.
        let status = try await UnifiedBatteryFeature.getStatus(
            on: transport,
            featureIndex: lookup.featureIndex
        )

        if json {
            let payload: [String: Any] = [
                "device": device.displayName,
                "productId": String(format: "0x%04X", device.productID),
                "percent": status.percent,
                "chargingState": "\(status.chargingState)",
                "externalPower": status.externalPower,
                "featureIndex": String(format: "0x%02X", lookup.featureIndex),
                "featureVersion": lookup.featureVersion,
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "{}")
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
                    "speaksHIDPP": device.speaksHIDPP,
                ]
                if let serial = device.serialNumber { dict["serial"] = serial }
                if let descriptor = DeviceRegistry.descriptor(for: device) {
                    dict["model"] = descriptor.modelName
                    dict["codename"] = descriptor.codename
                }
                return dict
            }
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(data: data, encoding: .utf8) ?? "[]")
            return
        }

        if devices.isEmpty {
            print("No Logitech HID devices found.")
            print("Tip: pair your mouse via Bluetooth or plug in a Bolt/Unifying receiver, then re-run.")
            return
        }

        print("Found \(devices.count) Logitech device\(devices.count == 1 ? "" : "s"):")
        print("")
        for device in devices {
            let pid = String(format: "0x%04X", device.productID)
            let descriptor = DeviceRegistry.descriptor(for: device)
            let badge = descriptor != nil ? "✅ supported" : (device.speaksHIDPP ? "🟡 HID++ (no descriptor)" : "⚪ generic HID")
            print("  • \(device.displayName)  [\(pid)]  \(badge)")
            print("      transport: \(device.transport ?? "unknown")  usage: \(String(format: "0x%04X/0x%04X", device.usagePage, device.usage))")
            if let descriptor {
                print("      model:     \(descriptor.modelName) (\(descriptor.codename))")
            }
            if let serial = device.serialNumber, !serial.isEmpty {
                print("      serial:    \(serial)")
            }
        }
        print("")
        print("Pass --json for machine-readable output, or --all to see every interface.")
    }
}

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diagnostic checks for Optune readiness."
    )

    func run() async throws {
        print("Optune \(OptuneCore.Optune.version) — readiness check")
        print("──────────────────────────────────────────────")

        // Check 1: any Logitech HID devices visible.
        let devices = HIDEnumerator.logitechDevices()
        if devices.isEmpty {
            print("✗ No Logitech HID devices visible. Check pairing/receiver/Bluetooth.")
        } else {
            print("✓ \(devices.count) Logitech HID interface\(devices.count == 1 ? "" : "s") visible")
        }

        // Check 2: known descriptors matched.
        let recognized = devices.compactMap { DeviceRegistry.descriptor(for: $0) }
        if recognized.isEmpty {
            print("✗ No devices matched a built-in descriptor (MVP only ships MX Master 3S).")
        } else {
            for descriptor in Set(recognized) {
                print("✓ Recognized: \(descriptor.modelName)")
            }
        }

        // Check 3: HID++ usage page reachable on at least one interface.
        // The MX Master 3S exposes HID++ via long reports (0x11) on usage page 0xFF43.
        let hidppCapable = devices.filter {
            DeviceRegistry.descriptor(for: $0) != nil || $0.speaksHIDPP
        }
        if hidppCapable.isEmpty {
            print("✗ No HID++-capable interface visible.")
        } else {
            print("✓ \(hidppCapable.count) HID++-capable interface\(hidppCapable.count == 1 ? "" : "s") detected")
        }

        // Check 4: actually try to open the device — this is what tells us whether
        // Input Monitoring (TCC kTCCServiceListenEvent) is granted.
        if let target = hidppCapable.first(where: { $0.isMXMaster3S }) ?? hidppCapable.first {
            do {
                let transport = try HIDPPTransport(matching: target)
                transport.close()
                print("✓ HID++ transport opens on \(target.displayName)")

                // Step further: try a Root.GetFeature(0x0000) round-trip with a short timeout.
                // If TCC silently drops the setReport, this times out.
                let probe = try HIDPPTransport(matching: target)
                defer { probe.close() }
                do {
                    _ = try await RootFeature.getFeature(on: probe, featureID: 0x0000)
                    print("✓ HID++ round-trip succeeds — Input Monitoring is granted")
                } catch HIDPPError.timeout {
                    print("✗ HID++ request timed out — likely Input Monitoring permission denied.")
                    print("  System Settings → Privacy & Security → Input Monitoring → toggle ON for this binary.")
                    print("  (TCC may have silently denied without showing a prompt; toggle the entry on/off to re-trigger.)")
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
