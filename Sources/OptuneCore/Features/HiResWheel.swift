import Foundation

/// HID++ 2.0 Feature `0x2121` — HiResWheel.
///
/// Modern Logitech mice (MX Master family) have a wheel with two physical
/// modes: ratcheted (clicky, 24 detents/rev) and freespin. This feature lets
/// us read the current mode + capabilities, and toggle:
/// - hi-res mode (1/8 step granularity)
/// - inversion
/// - ratchet vs freespin (where supported in software)
public enum HiResWheelFeature {
    public static let id: UInt16 = 0x2121

    public struct Capabilities: Sendable, Equatable, OptionSet {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let invertible    = Capabilities(rawValue: 0x08)
        public static let hasSwitch     = Capabilities(rawValue: 0x04)
        public static let hasRatchet    = Capabilities(rawValue: 0x02)
        public static let hasMultiplier = Capabilities(rawValue: 0x01)
    }

    public struct Mode: Sendable, Equatable, OptionSet {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let inverted    = Mode(rawValue: 0x08)
        public static let target      = Mode(rawValue: 0x04)
        public static let hiRes       = Mode(rawValue: 0x02)
        public static let analyticsKB = Mode(rawValue: 0x01)
    }

    public struct Status: Sendable, Equatable {
        public let multiplier: Int
        public let capabilities: Capabilities
        public let hasSwitchInRatchet: Bool
        public let mode: Mode
        public let isRatchet: Bool
    }

    public static func getCapabilities(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> (multiplier: Int, capabilities: Capabilities) {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard resp.params.count >= 2 else { throw HIDPPError.invalidResponse }
        return (Int(resp.params[0]), Capabilities(rawValue: resp.params[1]))
    }

    public static func getMode(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Mode {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x1)
        return Mode(rawValue: resp.params.first ?? 0)
    }

    @discardableResult
    public static func setMode(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        mode: Mode
    ) async throws -> Bool {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: [mode.rawValue]
        )
        return !resp.isError
    }

    public static func getRatchet(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Bool {
        // function 0x3 → [0=freespin, 1=ratchet]
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x3)
        return (resp.params.first ?? 0) == 1
    }

    @discardableResult
    public static func setRatchet(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        engaged: Bool
    ) async throws -> Bool {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x4,
            params: [engaged ? 1 : 0]
        )
        return !resp.isError
    }

    public static func snapshot(on transport: HIDPPTransport) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        let (mult, caps) = try await getCapabilities(on: transport, featureIndex: lookup.featureIndex)
        let mode = (try? await getMode(on: transport, featureIndex: lookup.featureIndex)) ?? Mode(rawValue: 0)
        let ratchet = (try? await getRatchet(on: transport, featureIndex: lookup.featureIndex)) ?? false
        return Status(
            multiplier: mult,
            capabilities: caps,
            hasSwitchInRatchet: caps.contains(.hasSwitch),
            mode: mode,
            isRatchet: ratchet
        )
    }
}

/// HID++ 2.0 Feature `0x2205` — Pointer Speed.
///
/// Multiplier applied on top of `AdjustableDPI`. Encoded as 8.8 fixed point;
/// 0x0100 = 1.0×, 0x0200 = 2.0×. Range typically 0.4×–2.0×.
public enum PointerSpeedFeature {
    public static let id: UInt16 = 0x2205

    public static func getSpeed(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Double {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard resp.params.count >= 2 else { throw HIDPPError.invalidResponse }
        let raw = (UInt16(resp.params[0]) << 8) | UInt16(resp.params[1])
        return Double(raw) / 256.0
    }

    @discardableResult
    public static func setSpeed(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        multiplier: Double
    ) async throws -> Double {
        let clamped = max(0.4, min(2.0, multiplier))
        let raw = UInt16(clamped * 256.0)
        let hi = UInt8((raw >> 8) & 0xFF)
        let lo = UInt8(raw & 0xFF)
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [hi, lo]
        )
        guard resp.params.count >= 2 else { throw HIDPPError.invalidResponse }
        let confirmed = (UInt16(resp.params[0]) << 8) | UInt16(resp.params[1])
        return Double(confirmed) / 256.0
    }
}
