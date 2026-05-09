import Foundation

/// HID++ 2.0 Feature `0x0005` — DeviceTypeAndName (the marketing name).
///
/// Three calls: getDeviceNameCount, getDeviceName(charIndex) (16 bytes per call),
/// getDeviceType. We assemble the ASCII string ourselves.
public enum DeviceNameFeature {
    public static let id: UInt16 = 0x0005

    public enum DeviceType: UInt8, Sendable {
        case keyboard = 0
        case remoteControl = 1
        case numpad = 2
        case mouse = 3
        case touchpad = 4
        case trackball = 5
        case presenter = 6
        case receiver = 7
        case headset = 8
        case webcam = 9
        case steeringWheel = 10
        case joystick = 11
        case gamepad = 12
        case dock = 13
        case speaker = 14
        case microphone = 15
        case illuminationLight = 16
        case unknown = 0xFF

        public var label: String {
            switch self {
            case .keyboard: return "Keyboard"
            case .remoteControl: return "Remote"
            case .numpad: return "Numpad"
            case .mouse: return "Mouse"
            case .touchpad: return "Touchpad"
            case .trackball: return "Trackball"
            case .presenter: return "Presenter"
            case .receiver: return "Receiver"
            case .headset: return "Headset"
            case .webcam: return "Webcam"
            case .steeringWheel: return "Wheel"
            case .joystick: return "Joystick"
            case .gamepad: return "Gamepad"
            case .dock: return "Dock"
            case .speaker: return "Speaker"
            case .microphone: return "Microphone"
            case .illuminationLight: return "Light"
            case .unknown: return "Device"
            }
        }
    }

    public struct DeviceInfo: Sendable, Equatable {
        public let name: String
        public let type: DeviceType
    }

    public static func getNameLength(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Int {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        return Int(resp.params.first ?? 0)
    }

    public static func getNameSlice(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        offset: UInt8
    ) async throws -> [UInt8] {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [offset]
        )
        return resp.params
    }

    public static func getDeviceType(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> DeviceType {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x2)
        return DeviceType(rawValue: resp.params.first ?? 0xFF) ?? .unknown
    }

    public static func snapshot(on transport: HIDPPTransport) async throws -> DeviceInfo {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else {
            return DeviceInfo(name: "", type: .unknown)
        }
        let length = try await getNameLength(on: transport, featureIndex: lookup.featureIndex)
        var name = ""
        var offset = 0
        while name.count < length, offset < length {
            let chunk = try await getNameSlice(on: transport, featureIndex: lookup.featureIndex, offset: UInt8(offset))
            let printable = chunk.prefix(min(16, length - offset)).filter { $0 >= 0x20 && $0 < 0x7F }
            if let s = String(bytes: printable, encoding: .ascii) {
                name += s
            }
            offset += 16
            if chunk.allSatisfy({ $0 == 0 }) { break }
        }
        let type = (try? await getDeviceType(on: transport, featureIndex: lookup.featureIndex)) ?? .unknown
        return DeviceInfo(name: name, type: type)
    }
}

/// HID++ 2.0 Feature `0x0007` — DeviceFriendlyName.
///
/// User-set nickname stored on device flash. Read with `getFriendlyName(offset)`,
/// write with `setFriendlyName(offset, bytes...)`. Some firmwares cap the name at
/// 14 ASCII chars — this enum clamps to that to keep writes safe.
public enum DeviceFriendlyNameFeature {
    public static let id: UInt16 = 0x0007
    public static let maxLength = 14

    public static func getNameLength(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Int {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        return Int(resp.params.first ?? 0)
    }

    public static func getName(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> String {
        let length = try await getNameLength(on: transport, featureIndex: featureIndex)
        var name = ""
        var offset = 0
        while offset < length, offset < 64 {
            let resp = try await transport.sendLong(
                featureIndex: featureIndex,
                function: 0x1,
                params: [UInt8(offset)]
            )
            // First byte echoes offset; rest is the slice
            let body = resp.params.dropFirst()
            let printable = body.prefix(min(15, length - offset)).filter { $0 >= 0x20 && $0 < 0x7F }
            if let s = String(bytes: printable, encoding: .ascii) {
                name += s
            }
            offset += 15
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    public static func setName(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        name: String
    ) async throws -> String {
        let clamped = String(name.prefix(maxLength))
        let bytes = Array(clamped.utf8.filter { $0 >= 0x20 && $0 < 0x7F })
        // Function 0x2 = setFriendlyName(offset, name...). Send in 14-char chunks.
        var offset: UInt8 = 0
        var i = 0
        while i < bytes.count {
            let slice = Array(bytes[i..<min(i + 14, bytes.count)])
            _ = try await transport.sendLong(
                featureIndex: featureIndex,
                function: 0x2,
                params: [offset] + slice
            )
            i += slice.count
            offset = UInt8(i)
        }
        return clamped
    }
}
