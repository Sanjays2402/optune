import ArgumentParser
import Foundation
import OptuneCore

@main
struct Optune: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "optune",
        abstract: "Configure Logitech devices on macOS — Logitech Options+ alternative.",
        version: OptuneCore.Optune.version,
        subcommands: [Devices.self, Doctor.self]
    )
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

        // Check 3: HID++-capable interface present.
        let hidpp = devices.filter { $0.speaksHIDPP }
        if hidpp.isEmpty {
            print("⚠ No HID++ interface visible. Optune needs Input Monitoring permission to talk to the device.")
            print("  Open System Settings → Privacy & Security → Input Monitoring and add `optune` / OptuneApp.")
        } else {
            print("✓ \(hidpp.count) HID++ interface\(hidpp.count == 1 ? "" : "s") reachable")
        }

        print("")
        print("Project: \(OptuneCore.Optune.projectURL)")
    }
}
