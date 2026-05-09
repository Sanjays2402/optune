import Foundation

/// HID++ 2.0 Feature 0x1004 — Unified Battery.
/// Reports state of charge, charging state, and external power presence
/// for modern Logitech devices (MX Master 3S included).
public enum UnifiedBatteryFeature {
    public static let id: UInt16 = 0x1004

    public enum ChargingState: UInt8, Sendable, CustomStringConvertible {
        case discharging = 0
        case charging = 1
        case chargingNearlyFull = 2
        case chargingComplete = 3
        case chargingError = 4
        case slowRecharge = 5
        case invalidBattery = 6
        case thermalError = 7
        case unknown = 0xFF

        public var description: String {
            switch self {
            case .discharging: return "discharging"
            case .charging: return "charging"
            case .chargingNearlyFull: return "charging (nearly full)"
            case .chargingComplete: return "charging complete"
            case .chargingError: return "charging error"
            case .slowRecharge: return "slow recharge"
            case .invalidBattery: return "invalid battery"
            case .thermalError: return "thermal error"
            case .unknown: return "unknown"
            }
        }
    }

    public struct Status: Sendable, Equatable {
        /// State of charge in percent (0...100).
        public let percent: UInt8
        /// Estimated remaining battery level in minutes (0 if unknown).
        public let chargingState: ChargingState
        /// Whether the device is on an external charger right now.
        public let externalPower: Bool

        public var description: String {
            let plug = externalPower ? " (on charger)" : ""
            return "\(percent)% — \(chargingState)\(plug)"
        }
    }

    /// `function = 0x1` GetStatus. Uses long reports for BLE-paired devices.
    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Status {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1
        )
        guard resp.params.count >= 3 else { throw HIDPPError.invalidResponse }
        let percent = resp.params[0]
        let stateRaw = resp.params[2]
        let state = ChargingState(rawValue: stateRaw) ?? .unknown
        let flags = resp.params.count > 3 ? resp.params[3] : 0
        // Bit 7 of batteryFlags is "external power present" on most firmwares.
        let externalPower = (flags & 0x80) != 0 || state == .charging
            || state == .chargingNearlyFull || state == .chargingComplete
        return Status(percent: percent, chargingState: state, externalPower: externalPower)
    }
}
