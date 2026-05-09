import Foundation

/// HID++ 2.0 Feature `0x1982` — Backlight2.
///
/// Controls keyboard backlight on devices like MX Keys S. The byte layout
/// matches Solaar's docs: a `getBacklightConfig` returns mode + level + supported
/// effects; `setBacklightConfig` writes mode + level + effect parameters.
///
/// We model only the basic knobs Optune needs: enabled/disabled, brightness
/// level (0–7 on most devices), and inactivity timeout (seconds × 5).
public enum Backlight2Feature {
    public static let id: UInt16 = 0x1982

    /// Backlight mode bytes. Logitech encodes "off" as 0, "auto" (proximity-aware)
    /// as 1, and "manual" (always on at level) as 2 on MX Keys.
    public enum Mode: UInt8, Sendable {
        case off    = 0
        case auto   = 1
        case manual = 2
        case unknown = 0xFF

        public var label: String {
            switch self {
            case .off: return "Off"
            case .auto: return "Auto (proximity)"
            case .manual: return "Always on"
            case .unknown: return "Unknown"
            }
        }
    }

    public struct Status: Sendable, Equatable {
        public let enabled: Bool
        public let mode: Mode
        public let level: UInt8         // 0...maxLevel
        public let maxLevel: UInt8
        public let durationOff: UInt16  // inactivity → off, seconds (× 5)
    }

    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Status {
        // function 0x0 — getBacklightConfig
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        let p = resp.params
        guard p.count >= 8 else { throw HIDPPError.invalidResponse }
        let enabled = (p[0] & 0x01) != 0
        let modeByte = (p[0] >> 1) & 0x07
        let mode = Mode(rawValue: modeByte) ?? .unknown
        let level = p[2]
        let maxLevel = p[3] == 0 ? 7 : p[3]
        // Bytes 4-5 = duration off (handsoff timeout, seconds × 5)
        let durOff: UInt16 = (UInt16(p[4]) << 8) | UInt16(p[5])
        return Status(
            enabled: enabled,
            mode: mode,
            level: level,
            maxLevel: maxLevel,
            durationOff: durOff
        )
    }

    public static func setStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        enabled: Bool,
        mode: Mode,
        level: UInt8
    ) async throws {
        // function 0x1 — setBacklightConfig
        var p = [UInt8](repeating: 0, count: 16)
        let modeByte: UInt8 = (mode == .unknown) ? 0 : (mode.rawValue & 0x07)
        p[0] = (enabled ? 0x01 : 0x00) | (modeByte << 1)
        p[1] = 0  // options reserved
        p[2] = level
        // Leave duration fields at zero — preserves device defaults.
        _ = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: p
        )
    }

    public static func snapshot(on transport: HIDPPTransport) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        return try await getStatus(on: transport, featureIndex: lookup.featureIndex)
    }
}

/// HID++ 2.0 Feature `0x40A3` — Fn Inversion (Multi-host).
///
/// Controls whether the F-row keys default to media/system actions (Fn-lock OFF,
/// the macOS default) or to F1–F12 (Fn-lock ON). Most modern Logitech keyboards
/// implement this as a per-host setting indexed 1...N.
public enum FnInversionFeature {
    public static let id: UInt16 = 0x40A3

    public struct Status: Sendable, Equatable {
        public let host: UInt8
        /// True = F-keys produce F1...F12. False = media/system (default).
        public let fnLockOn: Bool
        public let isInvertible: Bool
    }

    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        host: UInt8
    ) async throws -> Status {
        // function 0x0 — getGlobalFnInversion (host-aware)
        var params = [UInt8](repeating: 0, count: 16)
        params[0] = host
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x0,
            params: params
        )
        let p = resp.params
        guard p.count >= 3 else { throw HIDPPError.invalidResponse }
        let inverted = (p[1] & 0x01) != 0
        let invertible = (p[2] & 0x01) != 0
        return Status(host: p[0], fnLockOn: inverted, isInvertible: invertible)
    }

    public static func setStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        host: UInt8,
        fnLockOn: Bool
    ) async throws {
        // function 0x1 — setGlobalFnInversion
        var params = [UInt8](repeating: 0, count: 16)
        params[0] = host
        params[1] = fnLockOn ? 0x01 : 0x00
        _ = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: params
        )
    }

    public static func snapshot(
        on transport: HIDPPTransport,
        host: UInt8
    ) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        return try await getStatus(
            on: transport,
            featureIndex: lookup.featureIndex,
            host: host
        )
    }
}
