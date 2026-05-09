import ArgumentParser
import Foundation
import OptuneCore

// MARK: - fw

struct FirmwareCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fw",
        abstract: "Read firmware/bootloader/hardware version (HID++ feature 0x0003)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let entities = try await FirmwareInfoFeature.snapshot(on: transport)
        guard !entities.isEmpty else { throw CLIError.featureMissing("FirmwareInfo (0x0003)") }

        if json {
            try CLISupport.writeJSON([
                "device": device.displayName,
                "productId": String(format: "0x%04X", device.productID),
                "entities": entities.map { e in
                    [
                        "index": e.index,
                        "type": e.type.label,
                        "version": e.versionString
                    ] as [String: Any]
                }
            ])
            return
        }

        print("\(device.displayName) — \(entities.count) firmware entities")
        for e in entities {
            print(String(format: "  [%d] %-10s %@", e.index, (e.type.label as NSString).utf8String!, e.versionString))
        }
    }
}

// MARK: - name

struct NameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "name",
        abstract: "Read or set the device's friendly name (HID++ feature 0x0007)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex, e.g. 0xB034).")
    var pid: String?

    @Argument(help: "New name to write. Omit to read current.")
    var newName: String?

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: DeviceFriendlyNameFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("DeviceFriendlyName (0x0007)") }

        if let newName {
            let applied = try await DeviceFriendlyNameFeature.setName(
                on: transport,
                featureIndex: lookup.featureIndex,
                name: newName
            )
            print("\(device.displayName) — renamed to \"\(applied)\"")
        } else {
            let name = try await DeviceFriendlyNameFeature.getName(
                on: transport,
                featureIndex: lookup.featureIndex
            )
            print("\(device.displayName) — \"\(name)\"")
        }
    }
}

// MARK: - host

struct HostCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "host",
        abstract: "List paired hosts or switch the device to a different host (HID++ 0x1815/0x1814).",
        subcommands: [HostList.self, HostSwitch.self],
        defaultSubcommand: HostList.self
    )
}

struct HostList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List paired hosts and show which is active."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let hosts = try await HostsInfoFeature.snapshot(on: transport)
        if hosts.isEmpty { throw CLIError.featureMissing("HostsInfo (0x1815)") }

        if json {
            try CLISupport.writeJSON([
                "device": device.displayName,
                "hosts": hosts.map { h in
                    [
                        "index": h.index,
                        "current": h.isCurrent,
                        "paired": h.isPaired,
                        "paused": h.isPaused,
                        "os": h.os.label,
                        "name": h.name
                    ] as [String: Any]
                }
            ])
            return
        }

        print("\(device.displayName) — \(hosts.count) host slot(s)")
        for h in hosts {
            let marker = h.isCurrent ? "●" : "○"
            let state = h.isPaired ? (h.isPaused ? "paused" : "paired") : "unpaired"
            let display = h.name.isEmpty ? "<no name>" : h.name
            print(String(format: "  %@ [%d] %@  %@  %@", marker, h.index, h.os.label, display, state))
        }
    }
}

struct HostSwitch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "switch",
        abstract: "Switch the device to a paired host slot."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Argument(help: "Host slot to activate (0, 1, 2).")
    var slot: Int

    @Flag(help: "Force switch even if the target host has no active connection.")
    var force: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: ChangeHostFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("ChangeHost (0x1814)") }

        _ = try await ChangeHostFeature.setHost(
            on: transport,
            featureIndex: lookup.featureIndex,
            host: UInt8(slot),
            force: force
        )
        print("\(device.displayName) — switched to host slot \(slot). Device will reconnect on the new host.")
    }
}

// MARK: - profile

struct ProfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profile",
        abstract: "Inspect onboard profile state (HID++ feature 0x8100, read-only)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Flag(name: .shortAndLong, help: "Output JSON.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        guard let status = try await OnboardProfilesFeature.snapshot(on: transport) else {
            throw CLIError.featureMissing("OnboardProfiles (0x8100)")
        }

        if json {
            var payload: [String: Any] = [
                "device": device.displayName,
                "mode": status.mode.label,
                "activeProfile": status.activeProfile
            ]
            if let d = status.description {
                payload["description"] = [
                    "profileCount": d.profileCount,
                    "buttonCount": d.buttonCount,
                    "sectorCount": d.sectorCount,
                    "sectorSize": d.sectorSize
                ] as [String: Any]
            }
            try CLISupport.writeJSON(payload)
            return
        }

        print("\(device.displayName) — \(status.mode.label) mode, active profile #\(status.activeProfile)")
        if let d = status.description {
            print(String(format: "  profiles: %d (OOB %d)  buttons: %d  flash: %d × %dB",
                         d.profileCount, d.profileCountOOB, d.buttonCount, d.sectorCount, d.sectorSize))
        }
    }
}

// MARK: - wheel

struct WheelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wheel",
        abstract: "Read or toggle the scroll-wheel mode (HID++ feature 0x2121)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Flag(help: "Engage ratchet (clicky) mode.")
    var ratchet: Bool = false

    @Flag(help: "Engage freespin (smooth) mode.")
    var freespin: Bool = false

    @Flag(help: "Toggle inversion.")
    var invert: Bool = false

    @Flag(name: .shortAndLong, help: "Output JSON.")
    var json: Bool = false

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: HiResWheelFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("HiResWheel (0x2121)") }

        if ratchet || freespin {
            _ = try await HiResWheelFeature.setRatchet(
                on: transport,
                featureIndex: lookup.featureIndex,
                engaged: ratchet
            )
        }
        if invert {
            var mode = try await HiResWheelFeature.getMode(on: transport, featureIndex: lookup.featureIndex)
            if mode.contains(.inverted) {
                mode.remove(.inverted)
            } else {
                mode.insert(.inverted)
            }
            _ = try await HiResWheelFeature.setMode(on: transport, featureIndex: lookup.featureIndex, mode: mode)
        }

        guard let status = try await HiResWheelFeature.snapshot(on: transport) else { return }

        if json {
            try CLISupport.writeJSON([
                "device": device.displayName,
                "multiplier": status.multiplier,
                "isRatchet": status.isRatchet,
                "inverted": status.mode.contains(.inverted),
                "hiRes": status.mode.contains(.hiRes),
                "capabilities": [
                    "invertible": status.capabilities.contains(.invertible),
                    "hasSwitch": status.capabilities.contains(.hasSwitch),
                    "hasRatchet": status.capabilities.contains(.hasRatchet),
                    "hasMultiplier": status.capabilities.contains(.hasMultiplier)
                ]
            ])
            return
        }

        let modeLabel = status.isRatchet ? "ratchet" : "freespin"
        let invLabel = status.mode.contains(.inverted) ? ", inverted" : ""
        print("\(device.displayName) — wheel \(modeLabel), multiplier ×\(status.multiplier)\(invLabel)")
    }
}

// MARK: - speed

struct SpeedCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "speed",
        abstract: "Read or set the pointer-speed multiplier (HID++ feature 0x2205)."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Argument(help: "New speed multiplier (0.4 – 2.0). Omit to read current.")
    var multiplier: Double?

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: PointerSpeedFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("PointerSpeed (0x2205)") }

        if let multiplier {
            let applied = try await PointerSpeedFeature.setSpeed(
                on: transport,
                featureIndex: lookup.featureIndex,
                multiplier: multiplier
            )
            print(String(format: "%@ — pointer speed ×%.2f", device.displayName, applied))
        } else {
            let current = try await PointerSpeedFeature.getSpeed(
                on: transport,
                featureIndex: lookup.featureIndex
            )
            print(String(format: "%@ — pointer speed ×%.2f", device.displayName, current))
        }
    }
}

// MARK: - reset

struct ResetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Factory-reset the device (HID++ feature 0x0020). Destructive — requires --force."
    )

    @Option(name: .shortAndLong, help: "Specific PID to reset (hex).")
    var pid: String?

    @Flag(help: "Confirm. Without this, the command refuses to run.")
    var force: Bool = false

    func run() async throws {
        guard force else {
            FileHandle.standardError.write(Data("error: factory reset clears DPI presets, button assignments, and the friendly name. Pass --force to confirm.\n".utf8))
            throw ExitCode.failure
        }
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let lookup = try await RootFeature.getFeature(on: transport, featureID: ResetFeature.id)
        guard lookup.isPresent else { throw CLIError.featureMissing("Reset (0x0020)") }

        try await ResetFeature.reset(on: transport, featureIndex: lookup.featureIndex)
        print("\(device.displayName) — factory reset issued.")
    }
}

// MARK: - monitor

struct MonitorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Continuously poll battery + DPI + SmartShift and stream changes to stdout."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    @Option(help: "Poll interval in seconds (default 10).")
    var interval: Double = 10

    @Option(help: "Stop after N samples. 0 means run forever.")
    var samples: Int = 0

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var taken = 0
        while samples == 0 || taken < samples {
            taken += 1
            var line: [String: Any] = [
                "timestamp": dateFormatter.string(from: Date()),
                "device": device.displayName
            ]

            if let bat = try? await batterySnapshot(on: transport) {
                line["battery"] = bat
            }
            if let dpi = try? await AdjustableDPIFeature.snapshot(on: transport) {
                line["dpi"] = dpi.currentDPI
            }
            if let ss = (try? await SmartShiftFeature.snapshot(on: transport)) ?? nil {
                line["smartShift"] = ss.smartShiftEnabled
                line["smartShiftSensitivity"] = ss.autoDisengage
            }

            if let data = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8) {
                print(s)
                fflush(stdout)
            }

            if samples != 0 && taken >= samples { break }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func batterySnapshot(on transport: HIDPPTransport) async throws -> [String: Any] {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: UnifiedBatteryFeature.id)
        guard lookup.isPresent else { return [:] }
        let s = try await UnifiedBatteryFeature.getStatus(on: transport, featureIndex: lookup.featureIndex)
        return [
            "percent": s.percent,
            "chargingState": "\(s.chargingState)",
            "externalPower": s.externalPower
        ]
    }
}

// MARK: - export

struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Dump every readable HID++ feature for a device into a single JSON snapshot."
    )

    @Option(name: .shortAndLong, help: "Specific PID to query (hex).")
    var pid: String?

    func run() async throws {
        let device = try CLISupport.resolveDevice(pid: pid)
        let transport = try CLISupport.openTransport(for: device)
        defer { transport.close() }

        var snapshot: [String: Any] = [
            "device": device.displayName,
            "productId": String(format: "0x%04X", device.productID),
            "transport": device.transport ?? "unknown",
            "exportedAt": ISO8601DateFormatter().string(from: Date())
        ]

        if let lookup = try? await RootFeature.getFeature(on: transport, featureID: UnifiedBatteryFeature.id),
           lookup.isPresent,
           let status = try? await UnifiedBatteryFeature.getStatus(on: transport, featureIndex: lookup.featureIndex) {
            snapshot["battery"] = [
                "percent": status.percent,
                "chargingState": "\(status.chargingState)",
                "externalPower": status.externalPower
            ] as [String: Any]
        }

        if let dpi = try? await AdjustableDPIFeature.snapshot(on: transport) {
            snapshot["dpi"] = [
                "current": dpi.currentDPI,
                "default": dpi.defaultDPI as Any,
                "min": dpi.range.min,
                "max": dpi.range.max,
                "step": dpi.range.step as Any,
                "presets": dpi.range.presets
            ] as [String: Any]
        }

        if let ss = (try? await SmartShiftFeature.snapshot(on: transport)) ?? nil {
            snapshot["smartShift"] = [
                "enabled": ss.smartShiftEnabled,
                "autoDisengage": ss.autoDisengage,
                "defaultThreshold": ss.defaultThreshold
            ] as [String: Any]
        }

        if let buttons = try? await ReprogControlsV4Feature.snapshot(on: transport), !buttons.isEmpty {
            snapshot["buttons"] = buttons.map { ctrl in
                [
                    "index": ctrl.index,
                    "cid": String(format: "0x%04X", ctrl.cid),
                    "task": String(format: "0x%04X", ctrl.taskID),
                    "position": ctrl.position,
                    "isReprogrammable": ctrl.isReprogrammable
                ] as [String: Any]
            }
        }

        let entities = (try? await FirmwareInfoFeature.snapshot(on: transport)) ?? []
        if !entities.isEmpty {
            snapshot["firmware"] = entities.map { e in
                [
                    "type": e.type.label,
                    "version": e.versionString
                ] as [String: Any]
            }
        }

        if let info = try? await DeviceNameFeature.snapshot(on: transport) {
            snapshot["model"] = info.name
            snapshot["deviceType"] = info.type.label
        }

        let hosts = (try? await HostsInfoFeature.snapshot(on: transport)) ?? []
        if !hosts.isEmpty {
            snapshot["hosts"] = hosts.map { h in
                [
                    "index": h.index,
                    "current": h.isCurrent,
                    "os": h.os.label,
                    "name": h.name
                ] as [String: Any]
            }
        }

        if let onboard = (try? await OnboardProfilesFeature.snapshot(on: transport)) ?? nil {
            snapshot["onboard"] = [
                "mode": onboard.mode.label,
                "active": onboard.activeProfile,
                "profiles": onboard.description?.profileCount as Any
            ] as [String: Any]
        }

        if let wheel = (try? await HiResWheelFeature.snapshot(on: transport)) ?? nil {
            snapshot["wheel"] = [
                "isRatchet": wheel.isRatchet,
                "multiplier": wheel.multiplier,
                "inverted": wheel.mode.contains(.inverted)
            ] as [String: Any]
        }

        if let lookup = try? await RootFeature.getFeature(on: transport, featureID: PointerSpeedFeature.id),
           lookup.isPresent,
           let speed = try? await PointerSpeedFeature.getSpeed(on: transport, featureIndex: lookup.featureIndex) {
            snapshot["pointerSpeed"] = speed
        }

        try CLISupport.writeJSON(snapshot)
    }
}
