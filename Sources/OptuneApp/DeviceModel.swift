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
    var lastUpdated: Date?
}

@MainActor
final class DeviceModel: ObservableObject {
    @Published private(set) var devices: [LogitechDevice] = []
    @Published private(set) var lastRefresh: Date = .distantPast
    @Published private(set) var telemetry: DeviceTelemetry = DeviceTelemetry()
    @Published private(set) var isPolling: Bool = false

    private var refreshTask: Task<Void, Never>?
    private var telemetryTask: Task<Void, Never>?

    init() {
        refresh()
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

            let snapshot = DeviceTelemetry(
                battery: await battery,
                dpi: await dpi,
                smartShift: await smart,
                buttons: await buttons,
                lastUpdated: Date()
            )
            telemetry = snapshot
        } catch HIDPPError.deviceNotFound {
            telemetry = DeviceTelemetry(
                battery: .unavailable("Device not in registry"),
                dpi: .unavailable("Device not in registry"),
                smartShift: .unavailable("Device not in registry"),
                buttons: .unavailable("Device not in registry"),
                lastUpdated: Date()
            )
        } catch HIDPPError.openFailed(let r) {
            let msg = "Open failed (IOReturn=\(String(format: "0x%08X", r))) — grant Input Monitoring"
            telemetry = DeviceTelemetry(
                battery: .unavailable(msg),
                dpi: .unavailable(msg),
                smartShift: .unavailable(msg),
                buttons: .unavailable(msg),
                lastUpdated: Date()
            )
        } catch {
            let msg = "\(error)"
            telemetry = DeviceTelemetry(
                battery: .unavailable(msg),
                dpi: .unavailable(msg),
                smartShift: .unavailable(msg),
                buttons: .unavailable(msg),
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
}
