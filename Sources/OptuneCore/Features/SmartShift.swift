import Foundation

/// HID++ 2.0 Feature `0x2111` — SmartShift Enhanced.
///
/// Used by MX Master 3, 3S, and 4. Sets the scroll wheel between **ratchet**
/// (notched, slow) and **freespin** (frictionless, fast) modes, and configures
/// the auto-engage threshold (how hard you have to flick the wheel before it
/// switches into freespin).
///
/// Function set on the wire:
/// - 0x0 → getRatchetControlMode → returns `[mode, autoDisengage, defaultThreshold]`
/// - 0x1 → setRatchetControlMode → params: `[mode, autoDisengage, threshold]`
///
/// `mode`:   0x01 = freespin, 0x02 = ratchet, 0x00 = no change (read default).
/// `autoDisengage`: 1...50 → SmartShift active with that sensitivity threshold,
///                  0xFF   → fixed ratchet (SmartShift effectively disabled).
public enum SmartShiftFeature {
    public static let id: UInt16 = 0x2111

    public enum Mode: UInt8, Sendable, CustomStringConvertible {
        case freespin = 0x01
        case ratchet  = 0x02
        case noChange = 0x00

        public var description: String {
            switch self {
            case .freespin: return "freespin"
            case .ratchet:  return "ratchet"
            case .noChange: return "no change"
            }
        }
    }

    public struct Status: Sendable, Equatable {
        public let mode: Mode
        /// 1...50 → SmartShift enabled with that sensitivity, 0xFF → SmartShift OFF (fixed ratchet).
        public let autoDisengage: UInt8
        /// Firmware default threshold when none has been set yet.
        public let defaultThreshold: UInt8

        public var smartShiftEnabled: Bool {
            mode == .ratchet && autoDisengage >= 1 && autoDisengage <= 50
        }

        public var thresholdLabel: String {
            switch autoDisengage {
            case 0xFF: return "off (fixed ratchet)"
            case 1...50: return "threshold \(autoDisengage)"
            default: return "threshold \(autoDisengage)"
            }
        }
    }

    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Status {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x0
        )
        // Some firmwares return [mode, auto, defaultThreshold]; older ones drop default.
        guard let m = resp.params.first else { throw HIDPPError.invalidResponse }
        let mode = Mode(rawValue: m) ?? .noChange
        let auto = resp.params.count > 1 ? resp.params[1] : 0xFF
        let def = resp.params.count > 2 ? resp.params[2] : 25
        return Status(mode: mode, autoDisengage: auto, defaultThreshold: def)
    }

    /// Set SmartShift mode + threshold.
    /// - `mode`: target wheel mode (`.ratchet` is the typical one).
    /// - `enabled`: when `true`, SmartShift auto-disengage kicks in with `threshold`.
    ///              when `false`, SmartShift is disabled — wheel stays in `mode`.
    @discardableResult
    public static func setStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        mode: Mode = .ratchet,
        enabled: Bool = true,
        threshold: UInt8 = 25
    ) async throws -> Status {
        let auto: UInt8
        if enabled {
            auto = max(1, min(50, threshold))
        } else {
            auto = 0xFF
        }
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [mode.rawValue, auto, auto]
        )
        // Echo parsing — same shape as getStatus.
        let echoedMode = Mode(rawValue: resp.params.first ?? mode.rawValue) ?? mode
        let echoedAuto = resp.params.count > 1 ? resp.params[1] : auto
        let echoedDefault = resp.params.count > 2 ? resp.params[2] : threshold
        return Status(mode: echoedMode, autoDisengage: echoedAuto, defaultThreshold: echoedDefault)
    }

    /// One-shot helper: Root → SmartShift → snapshot. Returns `nil` if the
    /// device doesn't expose 0x2111 (older devices use 0x2110 Basic).
    public static func snapshot(
        on transport: HIDPPTransport
    ) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        return try await getStatus(on: transport, featureIndex: lookup.featureIndex)
    }
}
