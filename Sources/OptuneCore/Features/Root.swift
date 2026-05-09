import Foundation

/// HID++ 2.0 Feature 0x0000 — Root.
/// Used to enumerate which features the device exposes and at which feature index.
public enum RootFeature {
    public static let id: UInt16 = 0x0000

    /// Result of `Root.getFeature(featureID)` — a feature is present if `featureIndex != 0`.
    public struct FeatureLookup: Sendable, Equatable {
        public let featureIndex: UInt8
        public let featureType: UInt8
        public let featureVersion: UInt8

        public var isPresent: Bool { featureIndex != 0 }
    }

    /// Look up the feature index for a given HID++ feature ID.
    /// `Root` is always at feature index 0; we ask Root.GetFeature (function 0x0)
    /// with the desired feature ID as a 2-byte big-endian param.
    /// Uses long reports because BLE-paired devices often don't expose the short
    /// report ID (0x10) — only 0x11 — on the macOS HID interface.
    public static func getFeature(
        on transport: HIDPPTransport,
        featureID: UInt16
    ) async throws -> FeatureLookup {
        let hi = UInt8((featureID >> 8) & 0xFF)
        let lo = UInt8(featureID & 0xFF)
        let resp = try await transport.sendLong(
            featureIndex: 0x00,
            function: 0x0,
            params: [hi, lo]
        )
        // Response params: [featureIndex][featureType][featureVersion?]
        let idx = resp.params.first ?? 0
        let type = resp.params.count > 1 ? resp.params[1] : 0
        let version = resp.params.count > 2 ? resp.params[2] : 0
        return FeatureLookup(featureIndex: idx, featureType: type, featureVersion: version)
    }
}
