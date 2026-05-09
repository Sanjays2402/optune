import Foundation

/// HID++ 2.0 Feature `0x1814` — ChangeHost.
/// Switch the device to a paired host (slot 0/1/2). Multi-host MX Master 3S
/// supports three slots; the LED ring under the device shows the active one.
public enum ChangeHostFeature {
    public static let id: UInt16 = 0x1814

    public struct HostInfo: Sendable, Equatable {
        public let count: Int
        public let active: Int
    }

    public static func getHostInfo(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> HostInfo {
        // function 0x0 → [count][active]
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard resp.params.count >= 2 else { throw HIDPPError.invalidResponse }
        return HostInfo(count: Int(resp.params[0]), active: Int(resp.params[1]))
    }

    /// Switch to host slot `index`. Device disconnects immediately and reconnects
    /// on the new host. `force` true tells the firmware to skip its 'are you sure'
    /// debounce when the host doesn't currently have an active connection.
    @discardableResult
    public static func setHost(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        host: UInt8,
        force: Bool = false
    ) async throws -> Bool {
        // function 0x1 — setHost(hostIdx, force?)
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [host, force ? 1 : 0]
        )
        // Acknowledge frame just echoes; treat any non-error response as success.
        return !resp.isError
    }
}

/// HID++ 2.0 Feature `0x1815` — HostsInfo.
/// Returns metadata for each paired host: name, OS type, paused state,
/// last-seen Bluetooth address. We present this to users so they know which
/// slot belongs to which Mac/PC before slamming `optune host switch 1`.
public enum HostsInfoFeature {
    public static let id: UInt16 = 0x1815

    public enum HostOS: UInt8, Sendable {
        case unknown = 0
        case windows = 1
        case windowsEmbedded = 2
        case linux = 3
        case mac = 4
        case iOS = 5
        case android = 6
        case webOS = 7
        case chromeOS = 8
        case other = 0xFF

        public var label: String {
            switch self {
            case .unknown: return "Unknown"
            case .windows: return "Windows"
            case .windowsEmbedded: return "Win"
            case .linux: return "Linux"
            case .mac: return "macOS"
            case .iOS: return "iOS"
            case .android: return "Android"
            case .webOS: return "webOS"
            case .chromeOS: return "ChromeOS"
            case .other: return "Other"
            }
        }
    }

    public struct Host: Sendable, Equatable {
        public let index: Int
        public let isCurrent: Bool
        public let isPaired: Bool
        public let isPaused: Bool
        public let os: HostOS
        public let name: String
    }

    public static func getHostsCount(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> (count: Int, current: Int) {
        // function 0x0 → [count][current]
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard resp.params.count >= 2 else { throw HIDPPError.invalidResponse }
        return (Int(resp.params[0]), Int(resp.params[1]))
    }

    public static func getHost(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        index: Int,
        currentIndex: Int
    ) async throws -> Host {
        // function 0x1 (getHostInfo) → [hostIdx][status][bluetoothAddr 6 bytes][...nameSlot]
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [UInt8(index)]
        )
        let status = resp.params.count > 1 ? resp.params[1] : 0
        let isPaused = (status & 0x01) != 0
        let isPaired = (status & 0x02) != 0

        // Name + OS via function 0x2 (getHostFriendlyName)
        var name = ""
        var os: HostOS = .unknown
        do {
            let nameResp = try await transport.sendLong(
                featureIndex: featureIndex,
                function: 0x2,
                params: [UInt8(index), 0]   // offset 0
            )
            // Wire: [hostIdx][nameLen][osType][name bytes...]
            if nameResp.params.count >= 3 {
                let nameLen = Int(nameResp.params[1])
                os = HostOS(rawValue: nameResp.params[2]) ?? .unknown
                let body = Array(nameResp.params.dropFirst(3))
                let bytes = body.prefix(nameLen).filter { $0 >= 0x20 && $0 < 0x7F }
                name = String(bytes: bytes, encoding: .ascii) ?? ""
            }
        } catch {
            // Older firmware doesn't expose name slot — leave blank.
        }

        return Host(
            index: index,
            isCurrent: index == currentIndex,
            isPaired: isPaired,
            isPaused: isPaused,
            os: os,
            name: name
        )
    }

    public static func snapshot(on transport: HIDPPTransport) async throws -> [Host] {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return [] }
        let (count, current) = try await getHostsCount(on: transport, featureIndex: lookup.featureIndex)
        var hosts: [Host] = []
        for i in 0..<min(count, 4) {
            do {
                let h = try await getHost(
                    on: transport,
                    featureIndex: lookup.featureIndex,
                    index: i,
                    currentIndex: current
                )
                hosts.append(h)
            } catch {
                continue
            }
        }
        return hosts
    }
}
