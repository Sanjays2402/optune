import XCTest
@testable import OptuneCore

final class LogitechDeviceTests: XCTestCase {

    func test_displayName_fallsBackToHexPID_whenProductNameIsEmpty() {
        let device = LogitechDevice(
            productID: 0xB034,
            productName: "",
            manufacturer: "Logitech",
            usagePage: 0xFF43,
            usage: 0x0001
        )
        XCTAssertEqual(device.displayName, "Logitech device (PID 0xB034)")
    }

    func test_displayName_usesProductName_whenSet() {
        let device = LogitechDevice(
            productID: 0xB034,
            productName: "MX Master 3S",
            manufacturer: "Logitech",
            usagePage: 0xFF43,
            usage: 0x0001
        )
        XCTAssertEqual(device.displayName, "MX Master 3S")
    }

    func test_isMXMaster3S_matchesAllKnownPIDs() {
        for pid in [0xB034, 0x4082, 0x407B] {
            let device = LogitechDevice(
                productID: pid,
                productName: "",
                manufacturer: "Logitech",
                usagePage: HIDPP.usagePageVendorLong,
                usage: 0x0001
            )
            XCTAssertTrue(device.isMXMaster3S, "PID 0x\(String(pid, radix: 16, uppercase: true)) should match MX Master 3S")
        }
    }

    func test_isMXMaster3S_isFalse_forUnrelatedPIDs() {
        let device = LogitechDevice(
            productID: 0xC52B,
            productName: "Unifying Receiver",
            manufacturer: "Logitech",
            usagePage: 0x0001,
            usage: 0x0006
        )
        XCTAssertFalse(device.isMXMaster3S)
    }
}

final class HIDPPTests: XCTestCase {

    func test_vendorUsagePages_areWellKnown() {
        XCTAssertEqual(HIDPP.usagePageVendorShort, 0xFF00)
        XCTAssertEqual(HIDPP.usagePageVendorLong,  0xFF43)
    }

    func test_speaksHIDPP_recognisesVendorPages() {
        for page in [HIDPP.usagePageVendorShort, HIDPP.usagePageVendorLong, HIDPP.usagePageVendorConsumer] {
            let device = LogitechDevice(
                productID: 0xB034,
                productName: "",
                manufacturer: "Logitech",
                usagePage: page,
                usage: 0x0001
            )
            XCTAssertTrue(device.speaksHIDPP, "expected speaksHIDPP=true for usagePage 0x\(String(page, radix: 16, uppercase: true))")
        }
    }

    func test_speaksHIDPP_rejectsKeyboardPages() {
        let device = LogitechDevice(
            productID: 0xC52B,
            productName: "Receiver",
            manufacturer: "Logitech",
            usagePage: 0x0001,
            usage: 0x0006
        )
        XCTAssertFalse(device.speaksHIDPP)
    }

    func test_featureEnum_coversCoreHIDPPFeatures() {
        XCTAssertEqual(HIDPP.Feature.root.rawValue, 0x0000)
        XCTAssertEqual(HIDPP.Feature.batteryUnified.rawValue, 0x1004)
        XCTAssertEqual(HIDPP.Feature.adjustableDPI.rawValue, 0x2201)
    }
}

// DeviceRegistryTests moved to its own file (Tests/OptuneCoreTests/DeviceRegistryTests.swift)
// in v0.6.1 cleanup, to keep registry-specific assertions next to the new
// JSON-loading guards (test_devicesJSON_loadsFromBundle, test_directPIDs_areUniqueAcrossDevices,
// test_dpiBounds_areSane). Two `DeviceRegistryTests` classes in one module
// caused "invalid redeclaration" — only the dedicated file should define it now.

final class HIDEnumeratorTests: XCTestCase {
    func test_enumeration_isSafe_andReturnsArray() {
        // We can't assert hardware presence, only that the call is safe and returns a sortable array.
        let devices = HIDEnumerator.logitechDevices()
        XCTAssertGreaterThanOrEqual(devices.count, 0)
    }
}

final class OptuneMetadataTests: XCTestCase {

    func test_version_isSemverShaped() {
        let parts = OptuneCore.Optune.version.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        for part in parts {
            XCTAssertNotNil(Int(part))
        }
    }

    func test_projectURL_isPublicRepo() {
        XCTAssertEqual(OptuneCore.Optune.projectURL, "https://github.com/Sanjays2402/optune")
    }
}
