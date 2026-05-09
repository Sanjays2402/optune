import Foundation

/// Static information about a known Logitech device family.
/// Mirrors Logitune's per-device JSON descriptors but Swift-typed and built-in for the MVP.
public struct DeviceDescriptor: Sendable, Hashable, Codable {
    public let modelName: String
    public let codename: String
    public let pids: Set<Int>
    public let supportsBattery: Bool
    public let supportsDPI: Bool
    public let supportsSmartShift: Bool
    public let supportsThumbWheel: Bool
    public let supportsButtonRemap: Bool
    public let supportsGestures: Bool
    public let supportsSmoothScroll: Bool
    public let supportsEasySwitch: Bool

    public init(
        modelName: String,
        codename: String,
        pids: Set<Int>,
        supportsBattery: Bool = true,
        supportsDPI: Bool = true,
        supportsSmartShift: Bool = true,
        supportsThumbWheel: Bool = true,
        supportsButtonRemap: Bool = true,
        supportsGestures: Bool = true,
        supportsSmoothScroll: Bool = true,
        supportsEasySwitch: Bool = true
    ) {
        self.modelName = modelName
        self.codename = codename
        self.pids = pids
        self.supportsBattery = supportsBattery
        self.supportsDPI = supportsDPI
        self.supportsSmartShift = supportsSmartShift
        self.supportsThumbWheel = supportsThumbWheel
        self.supportsButtonRemap = supportsButtonRemap
        self.supportsGestures = supportsGestures
        self.supportsSmoothScroll = supportsSmoothScroll
        self.supportsEasySwitch = supportsEasySwitch
    }
}

/// Built-in registry of Logitech devices Optune has descriptors for.
/// MVP: MX Master 3S only. Roadmap: extend to MX Master 3, MX Master 4, MX Anywhere 3S.
public enum DeviceRegistry {

    public static let mxMaster3S = DeviceDescriptor(
        modelName: "MX Master 3S",
        codename: "mx-master-3s",
        // Bolt receiver, Unifying receiver, Bluetooth direct
        pids: [0xB034, 0x4082, 0x407B]
    )

    public static let all: [DeviceDescriptor] = [mxMaster3S]

    /// Match an enumerated device against the registry.
    public static func descriptor(for device: LogitechDevice) -> DeviceDescriptor? {
        all.first { $0.pids.contains(device.productID) }
    }
}
