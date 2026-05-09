import Foundation

/// HID++ 2.0 Feature `0x0003` — DeviceFwVersion / FirmwareInfo.
///
/// Returns the device's entity count, then per-entity firmware metadata.
/// Logitech mice typically expose 2-3 entities: `MAIN` (firmware), `BOOT`
/// (bootloader), `HW` (hardware revision string). Older devices stop at MAIN.
public enum FirmwareInfoFeature {
    public static let id: UInt16 = 0x0003

    public enum EntityType: UInt8, Sendable {
        case main      = 0
        case bootloader = 1
        case hardware  = 2
        case touchpad  = 3
        case opticalSensor = 4
        case softDevice = 5
        case rfCompanion = 6
        case factoryApp = 7
        case rgbCustomEffect = 8
        case motorDrive = 9
        case unknown   = 0xFF

        public var label: String {
            switch self {
            case .main: return "MAIN"
            case .bootloader: return "BOOT"
            case .hardware: return "HW"
            case .touchpad: return "TOUCHPAD"
            case .opticalSensor: return "SENSOR"
            case .softDevice: return "SOFTDEVICE"
            case .rfCompanion: return "RF"
            case .factoryApp: return "FACTORY"
            case .rgbCustomEffect: return "RGB"
            case .motorDrive: return "MOTOR"
            case .unknown: return "?"
            }
        }
    }

    public struct Entity: Sendable, Equatable {
        public let index: UInt8
        public let type: EntityType
        public let prefix: String   // 3 ASCII bytes, e.g. "RBM"
        public let major: UInt8     // BCD nibbles
        public let minor: UInt8
        public let build: UInt16

        public var versionString: String {
            String(format: "%@%02X.%02X_%04X", prefix, major, minor, build)
        }
    }

    /// `function = 0x0` — getDeviceInfo. Returns `[entityCount, ...]`.
    public static func getEntityCount(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Int {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        return Int(resp.params.first ?? 0)
    }

    /// `function = 0x1` — getFwInfo(entityIdx). Returns 13-byte payload.
    public static func getEntity(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        entityIndex: UInt8
    ) async throws -> Entity {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [entityIndex]
        )
        // Wire: [type][prefix0][prefix1][prefix2][maj][min][buildHi][buildLo]
        guard resp.params.count >= 8 else { throw HIDPPError.invalidResponse }
        let type = EntityType(rawValue: resp.params[0]) ?? .unknown
        let prefix = String(bytes: resp.params[1...3].filter { $0 >= 0x20 && $0 < 0x7F }, encoding: .ascii) ?? ""
        let major = resp.params[4]
        let minor = resp.params[5]
        let build = (UInt16(resp.params[6]) << 8) | UInt16(resp.params[7])
        return Entity(
            index: entityIndex,
            type: type,
            prefix: prefix,
            major: major,
            minor: minor,
            build: build
        )
    }

    /// Walks every entity and returns a sorted list. UI-friendly.
    public static func snapshot(on transport: HIDPPTransport) async throws -> [Entity] {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return [] }
        let count = try await getEntityCount(on: transport, featureIndex: lookup.featureIndex)
        var entities: [Entity] = []
        entities.reserveCapacity(count)
        for i in 0..<min(count, 8) {
            do {
                let e = try await getEntity(on: transport, featureIndex: lookup.featureIndex, entityIndex: UInt8(i))
                entities.append(e)
            } catch {
                continue
            }
        }
        return entities
    }
}
