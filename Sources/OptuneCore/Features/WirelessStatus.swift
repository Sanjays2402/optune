import Foundation

/// HID++ 2.0 Feature `0x1D4B` — WirelessDeviceStatus.
///
/// Read-only feature exposing the device's link state (idle/connected),
/// software/hardware-driven reconnect, and a "needs reconfiguration" flag the
/// firmware sets when it changes state behind the host's back (e.g. after a
/// host switch). We just surface the bits — the menu listens to them and
/// re-polls all features when reconfig is asserted.
public enum WirelessStatusFeature {
    public static let id: UInt16 = 0x1D4B

    public struct Status: Sendable, Equatable {
        public let needsReconfig: Bool
        public let reconnectionType: ReconnectionType
        public let reason: Reason

        public enum ReconnectionType: UInt8, Sendable {
            case unknown = 0
            case responseToReset = 1
            case unsolicited = 2
        }

        public enum Reason: UInt8, Sendable {
            case unknown = 0
            case powerSwitchActivated = 1
            case usbCableConnected = 2
            case usbCableDisconnected = 3
            case other = 0xFF
        }
    }

    /// Wireless status updates arrive as hardware-initiated events
    /// (`featureIndex == lookup, swID == 0`). We expose a parser so callers can
    /// route raw response payloads they collect via input-report listeners.
    public static func parse(payload: [UInt8]) -> Status {
        let needs = (payload.first ?? 0) & 0x01 != 0
        let recon = Status.ReconnectionType(rawValue: (payload.count > 1 ? payload[1] : 0)) ?? .unknown
        let reason = Status.Reason(rawValue: (payload.count > 2 ? payload[2] : 0)) ?? .unknown
        return Status(needsReconfig: needs, reconnectionType: recon, reason: reason)
    }
}

/// HID++ 2.0 Feature `0x0020` — Reset / Configuration Reset.
///
/// Single function: `reset` clears all customizations and reverts to factory
/// defaults. The CLI gates this behind `--force` and the GUI behind a confirm
/// sheet because it nukes button assignments, DPI presets, and the friendly
/// name in one go.
public enum ResetFeature {
    public static let id: UInt16 = 0x0020

    public static func reset(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws {
        // function 0x0 — resetConfiguration. No params, no response payload.
        _ = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
    }
}
