import Foundation

/// HID++ 2.0 Feature `0x2150` — ThumbWheel.
///
/// MX Master family has a horizontal thumb wheel on the side. Without
/// software intervention macOS sees it as nothing (or a stutter on the
/// horizontal scroll axis depending on firmware mode). Logitech Options+
/// drives this feature to:
/// - **Divert**: stop the firmware from emitting native scroll events and
///   instead fire HID++ notifications to the host (so userspace can
///   re-interpret them — pinch-zoom, app switching, custom scroll).
/// - **Invert**: reverse the scroll direction.
///
/// ## Wire format (function 0x10 read, 0x20 write)
/// Both functions take/return a 2-byte little-mask payload:
///   byte 0:  bit0 = diverted (1) / native (0)
///   byte 1:  bit0 = inverted (1) / normal  (0)
///
/// Read returns the current state; write echoes back the new state.
/// Source: Solaar `settings_templates.py` ThumbMode/ThumbInvert (rw_options
/// `read_fnid=0x10, write_fnid=0x20`).
public enum ThumbWheelFeature {
    public static let id: UInt16 = 0x2150

    public struct Status: Sendable, Equatable {
        public let diverted: Bool
        public let inverted: Bool
    }

    /// Read current diverted+inverted state. function 0x10 → `[divertedByte, invertedByte, 0…]`
    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Status {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x1)
        let div = (resp.params.first ?? 0) & 0x01
        let inv = (resp.params.count > 1 ? resp.params[1] : 0) & 0x01
        return Status(diverted: div != 0, inverted: inv != 0)
    }

    /// Write diverted+inverted state. function 0x20 → params `[divMask, invMask]`.
    /// Returns the firmware-echoed state.
    @discardableResult
    public static func setStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        diverted: Bool,
        inverted: Bool
    ) async throws -> Status {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: [diverted ? 0x01 : 0x00, inverted ? 0x01 : 0x00]
        )
        let echoDiv = (resp.params.first ?? (diverted ? 1 : 0)) & 0x01
        let echoInv = (resp.params.count > 1 ? resp.params[1] : (inverted ? 1 : 0)) & 0x01
        return Status(diverted: echoDiv != 0, inverted: echoInv != 0)
    }

    /// Convenience: lookup feature index then read.
    public static func snapshot(on transport: HIDPPTransport) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        return try await getStatus(on: transport, featureIndex: lookup.featureIndex)
    }
}
