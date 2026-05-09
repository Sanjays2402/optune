import Combine
import Foundation
import OptuneCore

/// One snapshot of a device's HID++ telemetry.
struct DeviceTelemetry: Equatable {
    enum Battery: Equatable {
        case unknown
        case unavailable(String)            // user-facing reason
        case ok(percent: UInt8, charging: Bool, externalPower: Bool)
    }

    var battery: Battery = .unknown
    var lastUpdated: Date?
}

@MainActor
final class DeviceModel: ObservableObject {
    @Published private(set) var devices: [LogitechDevice] = []
    @Published private(set) var lastRefresh: Date = .distantPast
    @Published private(set) var telemetry: DeviceTelemetry = DeviceTelemetry()

    private var refreshTask: Task<Void, Never>?
    private var telemetryTask: Task<Void, Never>?

    init() {
        refresh()
        // Cheap device-list poll every 4s. We could subscribe to IOKit notifications
        // later; polling is fine for the menu bar experience.
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.refresh()
            }
        }
        // Telemetry poll: opens HID++, reads battery, closes. Slow path → 60s.
        telemetryTask = Task { [weak self] in
            // First poll fires fast so the UI isn't blank for a minute.
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

    /// Force a telemetry refresh now (called from the Refresh menu row).
    func refreshTelemetryNow() {
        Task { await pollTelemetry() }
    }

    var recognizedDevices: [LogitechDevice] {
        devices.filter { DeviceRegistry.descriptor(for: $0) != nil }
    }

    var recognizedCount: Int {
        // De-duplicate multi-interface entries (Bolt receiver + paired mouse appear twice).
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
        let result = await Self.readBattery(for: device)
        telemetry = DeviceTelemetry(battery: result, lastUpdated: Date())
    }

    /// Open HID++, ask Root for Feature 0x1004, read UnifiedBattery status, close.
    /// Returns a `Battery` case suitable for direct UI binding.
    private static func readBattery(for device: LogitechDevice) async -> DeviceTelemetry.Battery {
        let transport: HIDPPTransport
        do {
            transport = try HIDPPTransport(matching: device)
        } catch HIDPPError.deviceNotFound {
            return .unavailable("Device not in IOKit registry")
        } catch HIDPPError.openFailed(let r) {
            return .unavailable("Open failed (IOReturn=\(String(format: "0x%08X", r)))")
        } catch {
            return .unavailable("\(error)")
        }
        defer { transport.close() }

        do {
            let lookup = try await RootFeature.getFeature(
                on: transport,
                featureID: UnifiedBatteryFeature.id
            )
            guard lookup.isPresent else {
                return .unavailable("UnifiedBattery (0x1004) not exposed")
            }
            let status = try await UnifiedBatteryFeature.getStatus(
                on: transport,
                featureIndex: lookup.featureIndex
            )
            let charging = status.chargingState == .charging
                || status.chargingState == .chargingNearlyFull
                || status.chargingState == .chargingComplete
            return .ok(
                percent: status.percent,
                charging: charging,
                externalPower: status.externalPower
            )
        } catch HIDPPError.timeout {
            return .unavailable("No reply — grant Input Monitoring to optune in System Settings")
        } catch let HIDPPError.errorResponse(featureIndex: f, function: fn, errorCode: code) {
            return .unavailable("HID++ err f=\(f) fn=\(fn) code=\(code)")
        } catch {
            return .unavailable("\(error)")
        }
    }
}
