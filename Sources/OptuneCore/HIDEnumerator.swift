import Foundation
import IOKit
import IOKit.hid

/// USB Vendor ID for Logitech (registered with USB-IF as `046D`).
public let logitechVendorID: Int = 0x046D

/// One physical or paired Logitech HID device discovered by IOKit.
public struct LogitechDevice: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let productID: Int
    public let productName: String
    public let manufacturer: String
    public let serialNumber: String?
    public let transport: String?
    public let usagePage: Int
    public let usage: Int
    public let locationID: UInt64?

    public init(
        id: UUID = UUID(),
        productID: Int,
        productName: String,
        manufacturer: String,
        serialNumber: String? = nil,
        transport: String? = nil,
        usagePage: Int,
        usage: Int,
        locationID: UInt64? = nil
    ) {
        self.id = id
        self.productID = productID
        self.productName = productName
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.transport = transport
        self.usagePage = usagePage
        self.usage = usage
        self.locationID = locationID
    }

    /// Best-guess human label even when IOKit returns no `kIOHIDProductKey`.
    public var displayName: String {
        if !productName.isEmpty { return productName }
        return String(format: "Logitech device (PID 0x%04X)", productID)
    }

    /// Heuristic: is this entry the MX Master 3S we care about for the MVP?
    public var isMXMaster3S: Bool {
        // Logitech assigns multiple PIDs depending on transport (Bolt vs Unifying vs BT).
        // MX Master 3S confirmed PIDs from logiops/Solaar tables.
        let mx3sPIDs: Set<Int> = [0xB034, 0x4082, 0x407B]
        return mx3sPIDs.contains(productID)
    }
}

/// Enumerates Logitech HID devices via IOKit. Pure, sync, no daemon.
public enum HIDEnumerator {

    /// All currently attached Logitech (vendor `0x046D`) HID devices.
    /// Returns `[]` (never throws) when IOKit refuses access — common for
    /// sandboxed contexts that haven't been granted Input Monitoring.
    public static func logitechDevices() -> [LogitechDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey: logitechVendorID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            // Fallback: enumeration without an open. This still returns metadata
            // for many devices on macOS without prompting for Input Monitoring.
            return enumerateWithoutOpen(manager: manager)
        }

        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        return enumerateWithoutOpen(manager: manager)
    }

    private static func enumerateWithoutOpen(manager: IOHIDManager) -> [LogitechDevice] {
        guard let raw = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }
        return raw
            .map(makeDevice(_:))
            .sorted { lhs, rhs in
                if lhs.productID != rhs.productID { return lhs.productID < rhs.productID }
                return lhs.displayName < rhs.displayName
            }
    }

    private static func makeDevice(_ device: IOHIDDevice) -> LogitechDevice {
        LogitechDevice(
            productID: intProperty(device, key: kIOHIDProductIDKey) ?? 0,
            productName: stringProperty(device, key: kIOHIDProductKey) ?? "",
            manufacturer: stringProperty(device, key: kIOHIDManufacturerKey) ?? "Logitech",
            serialNumber: stringProperty(device, key: kIOHIDSerialNumberKey),
            transport: stringProperty(device, key: kIOHIDTransportKey),
            usagePage: intProperty(device, key: kIOHIDPrimaryUsagePageKey) ?? 0,
            usage: intProperty(device, key: kIOHIDPrimaryUsageKey) ?? 0,
            locationID: uint64Property(device, key: kIOHIDLocationIDKey)
        )
    }

    private static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func intProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func uint64Property(_ device: IOHIDDevice, key: String) -> UInt64? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.uint64Value
    }
}
