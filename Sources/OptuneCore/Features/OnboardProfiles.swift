import Foundation

/// HID++ 2.0 Feature `0x8100` — Onboard Profiles.
///
/// Mice with on-device flash store up to 5 profiles (DPI, button mapping, RGB,
/// power schemes). v0.4 reads the onboard memory layout, profile descriptors,
/// and the active profile slot. Writing profiles is deferred to v0.5 — we want
/// to model the binary blob fully before letting users overwrite their flash.
public enum OnboardProfilesFeature {
    public static let id: UInt16 = 0x8100

    public enum Mode: UInt8, Sendable {
        case onboard = 1
        case host    = 2
        case unknown = 0xFF

        public var label: String {
            switch self {
            case .onboard: return "Onboard"
            case .host: return "Host"
            case .unknown: return "Unknown"
            }
        }
    }

    public struct Description: Sendable, Equatable {
        public let memoryModelID: UInt8
        public let profileFormatID: UInt8
        public let macroFormatID: UInt8
        public let profileCount: Int
        public let profileCountOOB: Int
        public let buttonCount: Int
        public let sectorCount: Int
        public let sectorSize: Int
        public let mechanicalLayout: UInt8
        public let variousInfo: UInt8
    }

    public struct Status: Sendable, Equatable {
        public let mode: Mode
        public let activeProfile: UInt8
        public let description: Description?
    }

    public static func getDescription(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Description {
        // function 0x0 — getOnboardProfilesDesc
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard resp.params.count >= 11 else { throw HIDPPError.invalidResponse }
        return Description(
            memoryModelID: resp.params[0],
            profileFormatID: resp.params[1],
            macroFormatID: resp.params[2],
            profileCount: Int(resp.params[3]),
            profileCountOOB: Int(resp.params[4]),
            buttonCount: Int(resp.params[5]),
            sectorCount: Int(resp.params[6]),
            sectorSize: (Int(resp.params[7]) << 8) | Int(resp.params[8]),
            mechanicalLayout: resp.params[9],
            variousInfo: resp.params[10]
        )
    }

    public static func getMode(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Mode {
        // function 0x1 — getActiveProfileMode
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x1)
        return Mode(rawValue: resp.params.first ?? 0xFF) ?? .unknown
    }

    public static func getActiveProfile(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> UInt8 {
        // function 0x4 — getActiveProfile
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x4)
        return resp.params.first ?? 0
    }

    /// Switch between onboard-profile mode (mouse runs from flash) and host-mode
    /// (driver pushes settings each session). function 0x2 — setActiveProfileMode.
    public static func setMode(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        mode: Mode
    ) async throws {
        var params = [UInt8](repeating: 0, count: 16)
        params[0] = mode.rawValue
        _ = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: params
        )
    }

    /// Switch the active onboard slot (1...profileCount). function 0x5 —
    /// setActiveProfile. Only meaningful when mode == .onboard.
    public static func setActiveProfile(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        profile: UInt8
    ) async throws {
        var params = [UInt8](repeating: 0, count: 16)
        params[0] = 0           // memory ID (0 = onboard flash)
        params[1] = profile     // 1-indexed
        _ = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x5,
            params: params
        )
    }

    public static func snapshot(on transport: HIDPPTransport) async throws -> Status? {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return nil }
        let mode = (try? await getMode(on: transport, featureIndex: lookup.featureIndex)) ?? .unknown
        let active = (try? await getActiveProfile(on: transport, featureIndex: lookup.featureIndex)) ?? 0
        let desc = try? await getDescription(on: transport, featureIndex: lookup.featureIndex)
        return Status(mode: mode, activeProfile: active, description: desc)
    }
}
