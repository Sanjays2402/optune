import Foundation

/// Static information about a known Logitech device family.
/// Mirrors Solaar/logiops/Mouser per-device tables but Swift-typed and built-in.
public struct DeviceDescriptor: Sendable, Hashable, Codable {
    public let modelName: String
    public let codename: String
    public let pids: Set<Int>

    /// Capability flags. Set to `false` only when we know the family lacks the
    /// hardware (e.g. MX Vertical has no thumb wheel). HID++ probing is still
    /// the source of truth at runtime.
    public let supportsBattery: Bool
    public let supportsDPI: Bool
    public let supportsSmartShift: Bool
    public let supportsThumbWheel: Bool
    public let supportsButtonRemap: Bool
    public let supportsGestures: Bool
    public let supportsSmoothScroll: Bool
    public let supportsEasySwitch: Bool

    /// Hardware DPI bounds. We clamp slider/CLI values to these.
    public let dpiMin: Int
    public let dpiMax: Int

    /// Default sensitivity threshold for SmartShift Enhanced (1...50).
    public let defaultSmartShiftThreshold: UInt8

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
        supportsEasySwitch: Bool = true,
        dpiMin: Int = 200,
        dpiMax: Int = 8000,
        defaultSmartShiftThreshold: UInt8 = 25
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
        self.dpiMin = dpiMin
        self.dpiMax = dpiMax
        self.defaultSmartShiftThreshold = defaultSmartShiftThreshold
    }
}

/// Built-in registry of Logitech devices Optune has descriptors for.
///
/// PIDs sourced from Solaar's `lib/logitech_receiver/descriptors.py` and Mouser's
/// `core/logi_devices.py`. When a device pairs over multiple transports
/// (Bluetooth direct vs Bolt receiver) only the **direct** PID is canonical;
/// the receiver enumerates as a separate USB device.
public enum DeviceRegistry {

    public static let mxMaster4 = DeviceDescriptor(
        modelName: "MX Master 4",
        codename: "mx-master-4",
        pids: [0xB042],
        supportsGestures: true,
        dpiMax: 8000
    )

    public static let mxMaster3S = DeviceDescriptor(
        modelName: "MX Master 3S",
        codename: "mx-master-3s",
        pids: [0xB034, 0x4082, 0x407B],
        supportsGestures: true,
        dpiMax: 8000
    )

    public static let mxMaster3 = DeviceDescriptor(
        modelName: "MX Master 3",
        codename: "mx-master-3",
        pids: [0xB023, 0x4082],
        supportsGestures: true,
        dpiMax: 4000
    )

    public static let mxMaster2S = DeviceDescriptor(
        modelName: "MX Master 2S",
        codename: "mx-master-2s",
        pids: [0xB019, 0x4069],
        supportsGestures: true,
        dpiMax: 4000
    )

    public static let mxMaster = DeviceDescriptor(
        modelName: "MX Master",
        codename: "mx-master",
        pids: [0xB012, 0x4041],
        supportsGestures: true,
        dpiMax: 4000
    )

    public static let mxVertical = DeviceDescriptor(
        modelName: "MX Vertical",
        codename: "mx-vertical",
        pids: [0xB020, 0x407B],
        supportsThumbWheel: false,
        supportsGestures: false,
        dpiMax: 4000
    )

    public static let mxAnywhere3S = DeviceDescriptor(
        modelName: "MX Anywhere 3S",
        codename: "mx-anywhere-3s",
        pids: [0xB037],
        supportsThumbWheel: false,
        supportsGestures: true,
        dpiMax: 8000
    )

    public static let mxAnywhere3 = DeviceDescriptor(
        modelName: "MX Anywhere 3",
        codename: "mx-anywhere-3",
        pids: [0xB025, 0x406A],
        supportsThumbWheel: false,
        supportsGestures: true,
        dpiMax: 4000
    )

    public static let mxAnywhere2S = DeviceDescriptor(
        modelName: "MX Anywhere 2S",
        codename: "mx-anywhere-2s",
        pids: [0xB01A, 0x406A],
        supportsThumbWheel: false,
        supportsGestures: true,
        dpiMax: 4000
    )

    public static let all: [DeviceDescriptor] = [
        mxMaster4, mxMaster3S, mxMaster3, mxMaster2S, mxMaster,
        mxVertical, mxAnywhere3S, mxAnywhere3, mxAnywhere2S
    ]

    /// Match an enumerated device against the registry.
    public static func descriptor(for device: LogitechDevice) -> DeviceDescriptor? {
        all.first { $0.pids.contains(device.productID) }
    }

    /// Clamp a DPI value to the device's hardware range.
    public static func clampDPI(_ value: Int, for descriptor: DeviceDescriptor?) -> Int {
        let lo = descriptor?.dpiMin ?? 200
        let hi = descriptor?.dpiMax ?? 8000
        return max(lo, min(hi, value))
    }
}

// MARK: - Convenience flags on LogitechDevice

extension LogitechDevice {
    /// Heuristic: does this entry look like an MX Master 3S across transports?
    public var isMXMaster3S: Bool {
        DeviceRegistry.mxMaster3S.pids.contains(productID)
    }

    /// Any of the MX Master family — useful for screenshot/UI defaulting.
    public var isMXMaster: Bool {
        let pids = DeviceRegistry.mxMaster.pids
            .union(DeviceRegistry.mxMaster2S.pids)
            .union(DeviceRegistry.mxMaster3.pids)
            .union(DeviceRegistry.mxMaster3S.pids)
            .union(DeviceRegistry.mxMaster4.pids)
        return pids.contains(productID)
    }
}
