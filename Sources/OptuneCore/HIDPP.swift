import Foundation

/// HID++ usage-page constants used by Logitech long-report devices.
/// Reference: HID++ 2.0 spec & Solaar/logiops device tables.
public enum HIDPP {
    /// Vendor-specific HID usage page where HID++ long reports live (`0xFF43`).
    public static let usagePageVendorLong: Int = 0xFF43

    /// Vendor-specific HID usage page where HID++ short reports live (`0xFF00`).
    public static let usagePageVendorShort: Int = 0xFF00

    /// Vendor-specific consumer-control page some Logitech devices expose (`0xFF01`).
    public static let usagePageVendorConsumer: Int = 0xFF01

    /// HID++ short report id (7-byte payload).
    public static let reportShort: UInt8 = 0x10

    /// HID++ long report id (20-byte payload).
    public static let reportLong: UInt8 = 0x11

    /// MVP-shipped HID++ feature ids we plan to implement next.
    public enum Feature: UInt16, CaseIterable, Sendable {
        case root             = 0x0000
        case featureSet       = 0x0001
        case deviceInfo       = 0x0003
        case deviceName       = 0x0005
        case batteryStatus    = 0x1000
        case batteryUnified   = 0x1004
        case adjustableDPI    = 0x2201
        case smartShift       = 0x2110
        case reprogControlsV4 = 0x1B04
        case smoothScroll     = 0x2121
    }
}

extension LogitechDevice {
    /// Whether the device exposes a HID++-bearing interface.
    /// Useful to filter out keyboard/dongle child entries that share vendor `0x046D`
    /// but don't speak HID++ (e.g. plain consumer-control surfaces).
    public var speaksHIDPP: Bool {
        switch usagePage {
        case HIDPP.usagePageVendorShort,
             HIDPP.usagePageVendorLong,
             HIDPP.usagePageVendorConsumer:
            return true
        default:
            return false
        }
    }
}
