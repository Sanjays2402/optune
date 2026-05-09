import Combine
import Foundation
import OptuneCore

/// One snapshot of a device's HID++ telemetry. UI-bindable.
struct DeviceTelemetry: Equatable {

    enum Battery: Equatable {
        case unknown
        case unavailable(String)
        case ok(percent: UInt8, charging: Bool, externalPower: Bool)

        var percent: Int? {
            if case .ok(let p, _, _) = self { return Int(p) } else { return nil }
        }

        var isCharging: Bool {
            if case .ok(_, let c, _) = self { return c } else { return false }
        }
    }

    enum DPI: Equatable {
        case unknown
        case unavailable(String)
        case ok(current: Int, min: Int, max: Int, step: Int?, defaultDPI: Int?)

        var current: Int? {
            if case .ok(let c, _, _, _, _) = self { return c } else { return nil }
        }
    }

    enum SmartShift: Equatable {
        case unknown
        case unavailable(String)
        case ok(enabled: Bool, threshold: UInt8, defaultThreshold: UInt8)
    }

    enum Buttons: Equatable {
        case unknown
        case unavailable(String)
        case ok(controls: [SerializableControl])

        var count: Int {
            if case .ok(let cs) = self { return cs.count } else { return 0 }
        }
    }

    enum Firmware: Equatable {
        case unknown
        case unavailable(String)
        case ok(entities: [Entity], serial: String?)

        struct Entity: Equatable, Identifiable, Hashable {
            let index: UInt8
            let kind: String
            let prefix: String
            let number: String
            let revision: String
            let build: UInt16
            var id: UInt8 { index }
            var displayVersion: String { "\(prefix)\(number).\(revision).\(build)" }
        }
    }

    enum Host: Equatable {
        case unknown
        case unavailable(String)
        case ok(currentHost: UInt8, hosts: [HostInfo])

        struct HostInfo: Equatable, Identifiable, Hashable {
            let index: UInt8
            let isPaired: Bool
            let isCurrent: Bool
            let name: String
            var id: UInt8 { index }
        }
    }

    enum Wheel: Equatable {
        case unknown
        case unavailable(String)
        case ok(invert: Bool, ratchet: Bool, multiplier: UInt8)
    }

    enum PointerSpeed: Equatable {
        case unknown
        case unavailable(String)
        case ok(level: UInt8, multiplier: Double)
    }

    enum WirelessLink: Equatable {
        case unknown
        case unavailable(String)
        case ok(linkOK: Bool, isPowerSwitch: Bool)
    }

    /// Sendable, Equatable mirror of `ReprogControlsV4Feature.Control`. Lets us
    /// keep `DeviceTelemetry` Equatable and pass it through `@Published`.
    struct SerializableControl: Equatable, Identifiable, Hashable {
        var id: UInt8 { index }
        let index: UInt8
        let cid: UInt16
        let name: String
        let isReprogrammable: Bool
        let isMouseButton: Bool
        let position: UInt8
    }

    var battery: Battery = .unknown
    var dpi: DPI = .unknown
    var smartShift: SmartShift = .unknown
    var buttons: Buttons = .unknown
    var firmware: Firmware = .unknown
    var hosts: Host = .unknown
    var wheel: Wheel = .unknown
    var pointerSpeed: PointerSpeed = .unknown
    var wirelessLink: WirelessLink = .unknown
    var lastUpdated: Date?
}

@MainActor
final class DeviceModel: ObservableObject {
    @Published private(set) var devices: [LogitechDevice] = []
    @Published private(set) var lastRefresh: Date = .distantPast
    @Published private(set) var telemetry: DeviceTelemetry = DeviceTelemetry()
    @Published private(set) var isPolling: Bool = false
    @Published private(set) var deviceNickname: String = ""

    private var refreshTask: Task<Void, Never>?
    private var telemetryTask: Task<Void, Never>?
    private var sleepObserver: SleepObserver?
    private let store = SettingsStore.shared

    init() {
        refresh()
        OptuneNotifications.shared.requestAuthorizationIfNeeded()
        sleepObserver = SleepObserver { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.refreshTelemetryNow()
            }
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.refresh()
            }
        }
        telemetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            while !Task.isCancelled {
                await self?.pollTelemetry()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        telemetryTask?.cancel()
    }

    func refresh() {
        let next = HIDEnumerator.logitechDevices()
        self.devices = next
        self.lastRefresh = Date()
    }

    func refreshTelemetryNow() {
        Task { await pollTelemetry() }
    }

    /// Push a new DPI to the device, then refresh telemetry. UI calls this
    /// when the slider commits a value.
    func applyDPI(_ value: Int) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeDPI(value, to: device)
            await self.pollTelemetry()
        }
    }

    /// Toggle SmartShift on/off (keeps the current threshold).
    func setSmartShiftEnabled(_ enabled: Bool, threshold: UInt8? = nil) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeSmartShift(enabled: enabled, threshold: threshold, on: device)
            self.store.update(for: device) { settings in
                settings.smartShiftEnabled = enabled
                if let threshold { settings.smartShiftThreshold = threshold }
            }
            await self.pollTelemetry()
        }
    }

    /// Switch wheel ratchet/freespin without touching invert.
    func setWheelRatchet(_ ratchet: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeWheelRatchet(ratchet, on: device)
            self.store.update(for: device) { $0.wheelRatchet = ratchet }
            await self.pollTelemetry()
        }
    }

    /// Toggle invert on the wheel.
    func setWheelInverted(_ inverted: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeWheelInverted(inverted, on: device)
            self.store.update(for: device) { $0.wheelInverted = inverted }
            await self.pollTelemetry()
        }
    }

    /// Apply pointer-speed multiplier (0x2205) — clamps 0.4–2.0.
    func setPointerSpeed(_ multiplier: Double) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writePointerSpeed(multiplier, on: device)
            self.store.update(for: device) { $0.pointerSpeedMultiplier = multiplier }
            await self.pollTelemetry()
        }
    }

    /// Switch host (0x1814) — moves the device to a different paired host.
    func switchHost(to index: UInt8) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeHostSwitch(to: index, on: device)
            // After switch the device drops from this host — re-enumerate.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.refresh()
        }
    }

    /// Set the device's nickname (0x0007). Truncated to 14 ASCII chars.
    func setNickname(_ name: String) {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            let written = await Self.writeNickname(name, on: device)
            self.deviceNickname = written
            self.store.update(for: device) { $0.nickname = written }
        }
    }

    /// Factory-reset the primary device (0x0020). Caller is responsible for confirmation.
    func factoryReset() {
        Task { [weak self] in
            guard let self else { return }
            guard let device = self.primaryDevice else { return }
            await Self.writeReset(on: device)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.refresh()
            await self.pollTelemetry()
        }
    }

    var recognizedDevices: [LogitechDevice] {
        devices.filter { DeviceRegistry.descriptor(for: $0) != nil }
    }

    var recognizedCount: Int {
        Set(recognizedDevices.compactMap { DeviceRegistry.descriptor(for: $0)?.codename }).count
    }

    var primaryDevice: LogitechDevice? {
        recognizedDevices.first(where: { $0.isMXMaster3S }) ?? recognizedDevices.first
    }

    var primaryDescriptor: DeviceDescriptor? {
        guard let primaryDevice else { return nil }
        return DeviceRegistry.descriptor(for: primaryDevice)
    }

    // MARK: - Telemetry

    private func pollTelemetry() async {
        guard let device = primaryDevice else {
            telemetry = DeviceTelemetry()
            return
        }
        isPolling = true
        defer { isPolling = false }

        // One transport per poll keeps things simple — we close it on every cycle.
        // If transport open fails (TCC denied, device gone) all four telemetry
        // slots get marked .unavailable with the same reason.
        do {
            let transport = try HIDPPTransport(matching: device)
            defer { transport.close() }

            async let battery = Self.readBattery(transport)
            async let dpi = Self.readDPI(transport)
            async let smart = Self.readSmartShift(transport)
            async let buttons = Self.readButtons(transport)
            async let firmware = Self.readFirmware(transport)
            async let hosts = Self.readHosts(transport)
            async let wheel = Self.readWheel(transport)
            async let pointerSpeed = Self.readPointerSpeed(transport)
            async let nickname = Self.readNickname(transport)

            let (b, d, s, btn, fw, hs, wh, ps, nick) = await (
                battery, dpi, smart, buttons, firmware, hosts, wheel, pointerSpeed, nickname
            )

            let snapshot = DeviceTelemetry(
                battery: b,
                dpi: d,
                smartShift: s,
                buttons: btn,
                firmware: fw,
                hosts: hs,
                wheel: wh,
                pointerSpeed: ps,
                wirelessLink: .unknown,
                lastUpdated: Date()
            )
            telemetry = snapshot
            if !nick.isEmpty { deviceNickname = nick }

            // Persist battery sample + fire low-battery notification.
            if case .ok(let percent, let charging, _) = b {
                store.recordBattery(percent: Int(percent), charging: charging, for: device)
                let key = "\(device.productID):\(device.serialNumber ?? "?")"
                let stored = store.settings(for: device).nickname
                let resolved: String
                if let stored, !stored.isEmpty {
                    resolved = stored
                } else if !deviceNickname.isEmpty {
                    resolved = deviceNickname
                } else {
                    resolved = DeviceRegistry.descriptor(for: device)?.modelName ?? "Mouse"
                }
                let label = resolved
                OptuneNotifications.shared.notifyLowBattery(
                    deviceKey: key,
                    deviceLabel: label,
                    percent: Int(percent),
                    threshold: store.app.lowBatteryThreshold,
                    enabled: store.app.lowBatteryNotificationsEnabled
                )
            }
        } catch HIDPPError.deviceNotFound {
            telemetry = DeviceTelemetry(
                battery: .unavailable("Device not in registry"),
                dpi: .unavailable("Device not in registry"),
                smartShift: .unavailable("Device not in registry"),
                buttons: .unavailable("Device not in registry"),
                firmware: .unavailable("Device not in registry"),
                hosts: .unavailable("Device not in registry"),
                wheel: .unavailable("Device not in registry"),
                pointerSpeed: .unavailable("Device not in registry"),
                wirelessLink: .unavailable("Device not in registry"),
                lastUpdated: Date()
            )
        } catch HIDPPError.openFailed(let r) {
            let msg = "Open failed (IOReturn=\(String(format: "0x%08X", r))) — grant Input Monitoring"
            telemetry = DeviceTelemetry(
                battery: .unavailable(msg),
                dpi: .unavailable(msg),
                smartShift: .unavailable(msg),
                buttons: .unavailable(msg),
                firmware: .unavailable(msg),
                hosts: .unavailable(msg),
                wheel: .unavailable(msg),
                pointerSpeed: .unavailable(msg),
                wirelessLink: .unavailable(msg),
                lastUpdated: Date()
            )
        } catch {
            let msg = "\(error)"
            telemetry = DeviceTelemetry(
                battery: .unavailable(msg),
                dpi: .unavailable(msg),
                smartShift: .unavailable(msg),
                buttons: .unavailable(msg),
                firmware: .unavailable(msg),
                hosts: .unavailable(msg),
                wheel: .unavailable(msg),
                pointerSpeed: .unavailable(msg),
                wirelessLink: .unavailable(msg),
                lastUpdated: Date()
            )
        }
    }

    // MARK: - Per-feature readers

    private static func readBattery(_ transport: HIDPPTransport) async -> DeviceTelemetry.Battery {
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: UnifiedBatteryFeature.id)
            guard lookup.isPresent else { return .unavailable("UnifiedBattery (0x1004) not exposed") }
            let status = try await UnifiedBatteryFeature.getStatus(on: transport, featureIndex: lookup.featureIndex)
            let charging = [
                .charging, .chargingNearlyFull, .chargingComplete
            ].contains(status.chargingState)
            return .ok(percent: status.percent, charging: charging, externalPower: status.externalPower)
        } catch HIDPPError.timeout {
            return .unavailable("No reply — grant Input Monitoring to optune")
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readDPI(_ transport: HIDPPTransport) async -> DeviceTelemetry.DPI {
        do {
            let snap = try await AdjustableDPIFeature.snapshot(on: transport)
            return .ok(
                current: snap.currentDPI,
                min: snap.range.min,
                max: snap.range.max,
                step: snap.range.step,
                defaultDPI: snap.defaultDPI
            )
        } catch HIDPPError.invalidResponse {
            return .unavailable("0x2201 not exposed")
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readSmartShift(_ transport: HIDPPTransport) async -> DeviceTelemetry.SmartShift {
        do {
            guard let status = try await SmartShiftFeature.snapshot(on: transport) else {
                return .unavailable("0x2111 not exposed")
            }
            return .ok(
                enabled: status.smartShiftEnabled,
                threshold: status.autoDisengage == 0xFF ? status.defaultThreshold : status.autoDisengage,
                defaultThreshold: status.defaultThreshold
            )
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readButtons(_ transport: HIDPPTransport) async -> DeviceTelemetry.Buttons {
        do {
            let controls = try await ReprogControlsV4Feature.snapshot(on: transport)
            guard !controls.isEmpty else { return .unavailable("0x1B04 not exposed") }
            let serial = controls.map { c in
                DeviceTelemetry.SerializableControl(
                    index: c.index,
                    cid: c.cid,
                    name: c.friendlyName,
                    isReprogrammable: c.isReprogrammable,
                    isMouseButton: c.isMouseButton,
                    position: c.position
                )
            }
            return .ok(controls: serial)
        } catch {
            return .unavailable("\(error)")
        }
    }

    // MARK: - Writers

    private static func writeDPI(_ value: Int, to device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: AdjustableDPIFeature.id)
            guard lookup.isPresent else { return }
            let descriptor = DeviceRegistry.descriptor(for: device)
            let clamped = DeviceRegistry.clampDPI(value, for: descriptor)
            _ = try await AdjustableDPIFeature.setDPI(
                on: transport,
                featureIndex: lookup.featureIndex,
                dpi: clamped
            )
        } catch {
            // Surfaced via next telemetry poll's .unavailable fallback.
        }
    }

    private static func writeSmartShift(enabled: Bool, threshold: UInt8?, on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: SmartShiftFeature.id)
            guard lookup.isPresent else { return }
            let target = threshold ?? 25
            _ = try await SmartShiftFeature.setStatus(
                on: transport,
                featureIndex: lookup.featureIndex,
                mode: .ratchet,
                enabled: enabled,
                threshold: target
            )
        } catch { }
    }

    // MARK: - v0.4 readers

    private static func readFirmware(_ transport: HIDPPTransport) async -> DeviceTelemetry.Firmware {
        do {
            let entities = try await FirmwareInfoFeature.snapshot(on: transport)
            guard !entities.isEmpty else { return .unavailable("0x0003 not exposed") }
            let mapped = entities.map {
                DeviceTelemetry.Firmware.Entity(
                    index: $0.index,
                    kind: $0.type.label,
                    prefix: $0.prefix,
                    number: String(format: "%02X", $0.major),
                    revision: String(format: "%02X", $0.minor),
                    build: $0.build
                )
            }
            return .ok(entities: mapped, serial: nil)
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readHosts(_ transport: HIDPPTransport) async -> DeviceTelemetry.Host {
        do {
            let hosts = try await HostsInfoFeature.snapshot(on: transport)
            guard !hosts.isEmpty else { return .unavailable("0x1815 not exposed") }
            let current = UInt8(hosts.first(where: \.isCurrent)?.index ?? hosts[0].index)
            let mapped = hosts.map {
                DeviceTelemetry.Host.HostInfo(
                    index: UInt8($0.index),
                    isPaired: $0.isPaired,
                    isCurrent: $0.isCurrent,
                    name: $0.name.isEmpty
                        ? "Host \($0.index + 1) (\($0.os.label))"
                        : "\($0.name) (\($0.os.label))"
                )
            }
            return .ok(currentHost: current, hosts: mapped)
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readWheel(_ transport: HIDPPTransport) async -> DeviceTelemetry.Wheel {
        do {
            guard let status = try await HiResWheelFeature.snapshot(on: transport) else {
                return .unavailable("0x2121 not exposed")
            }
            return .ok(
                invert: status.mode.contains(.inverted),
                ratchet: status.isRatchet,
                multiplier: UInt8(clamping: status.multiplier)
            )
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readPointerSpeed(_ transport: HIDPPTransport) async -> DeviceTelemetry.PointerSpeed {
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: PointerSpeedFeature.id)
            guard lookup.isPresent else { return .unavailable("0x2205 not exposed") }
            let multiplier = try await PointerSpeedFeature.getSpeed(on: transport, featureIndex: lookup.featureIndex)
            // We don't store discrete level here — UI surfaces the multiplier directly.
            return .ok(level: 0, multiplier: multiplier)
        } catch {
            return .unavailable("\(error)")
        }
    }

    private static func readNickname(_ transport: HIDPPTransport) async -> String {
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: DeviceFriendlyNameFeature.id)
            guard lookup.isPresent else { return "" }
            return try await DeviceFriendlyNameFeature.getName(on: transport, featureIndex: lookup.featureIndex)
        } catch {
            return ""
        }
    }

    // MARK: - v0.4 writers

    private static func writeWheelRatchet(_ ratchet: Bool, on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: HiResWheelFeature.id)
            guard lookup.isPresent else { return }
            _ = try await HiResWheelFeature.setRatchet(
                on: transport,
                featureIndex: lookup.featureIndex,
                engaged: ratchet
            )
        } catch { }
    }

    private static func writeWheelInverted(_ inverted: Bool, on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: HiResWheelFeature.id)
            guard lookup.isPresent else { return }
            // Read current mode, flip the inverted bit, write back.
            let current = try await HiResWheelFeature.getMode(
                on: transport,
                featureIndex: lookup.featureIndex
            )
            var next = current
            if inverted {
                next.insert(.inverted)
            } else {
                next.remove(.inverted)
            }
            _ = try await HiResWheelFeature.setMode(
                on: transport,
                featureIndex: lookup.featureIndex,
                mode: next
            )
        } catch { }
    }

    private static func writePointerSpeed(_ multiplier: Double, on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: PointerSpeedFeature.id)
            guard lookup.isPresent else { return }
            _ = try await PointerSpeedFeature.setSpeed(
                on: transport,
                featureIndex: lookup.featureIndex,
                multiplier: multiplier
            )
        } catch { }
    }

    private static func writeHostSwitch(to index: UInt8, on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: ChangeHostFeature.id)
            guard lookup.isPresent else { return }
            _ = try await ChangeHostFeature.setHost(
                on: transport,
                featureIndex: lookup.featureIndex,
                host: index
            )
        } catch { }
    }

    private static func writeNickname(_ name: String, on device: LogitechDevice) async -> String {
        guard let transport = try? HIDPPTransport(matching: device) else { return name }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: DeviceFriendlyNameFeature.id)
            guard lookup.isPresent else { return name }
            return try await DeviceFriendlyNameFeature.setName(
                on: transport,
                featureIndex: lookup.featureIndex,
                name: name
            )
        } catch {
            return name
        }
    }

    private static func writeReset(on device: LogitechDevice) async {
        guard let transport = try? HIDPPTransport(matching: device) else { return }
        defer { transport.close() }
        do {
            let lookup = try await RootFeature.getFeature(on: transport, featureID: ResetFeature.id)
            guard lookup.isPresent else { return }
            try await ResetFeature.reset(on: transport, featureIndex: lookup.featureIndex)
        } catch { }
    }
}
