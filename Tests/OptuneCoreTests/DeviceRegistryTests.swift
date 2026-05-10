import XCTest
@testable import OptuneCore

final class DeviceRegistryTests: XCTestCase {
    /// `DeviceRegistry.all` must be populated — either from the bundled
    /// `devices.json` resource or the Swift fallback. An empty registry
    /// means the bundle resource is broken AND the fallback is empty.
    func testRegistryLoads() throws {
        XCTAssertFalse(DeviceRegistry.all.isEmpty,
                       "DeviceRegistry.all should not be empty — devices.json may be malformed")
    }

    /// Sanity check on the canonical MX Master 3S — must always match
    /// the Bolt receiver PID `0xB034` regardless of load source.
    func testMxMaster3SLookup() {
        let device = LogitechDevice(
            productID: 0xB034,
            productName: "MX Master 3S",
            manufacturer: "Logitech",
            transport: "USB",
            usagePage: 0xFF43,
            usage: 0x0202
        )
        let descriptor = DeviceRegistry.descriptor(for: device)
        XCTAssertNotNil(descriptor, "MX Master 3S Bolt PID 0xB034 must match a descriptor")
        XCTAssertEqual(descriptor?.codename, "mx-master-3s")
    }

    /// PIDs must not collide across descriptors — a single PID matching
    /// two model families would make `descriptor(for:)` non-deterministic.
    /// Note: 0x4082 / 0x407B / 0x406A are shared *receiver* PIDs across
    /// transport variants — these are intentionally listed under multiple
    /// devices because the receiver enumerates as one IOKit entry per
    /// paired peripheral. We only flag direct (`0xBxxx`) PID collisions.
    func testNoDirectPIDCollisions() {
        var seen: [Int: String] = [:]
        for desc in DeviceRegistry.all {
            for pid in desc.pids where pid >= 0xB000 && pid < 0xC000 {
                if let existing = seen[pid] {
                    XCTFail("Direct PID 0x\(String(pid, radix: 16, uppercase: true)) appears in both \(existing) and \(desc.codename)")
                }
                seen[pid] = desc.codename
            }
        }
    }

    /// DPI bounds must be sane: positive, min < max, max ≤ 32000 (no
    /// realistic mouse hits 32K — typo guard).
    func testDPIBoundsAreSane() {
        for desc in DeviceRegistry.all {
            XCTAssertGreaterThan(desc.dpiMin, 0, "\(desc.codename): dpiMin must be > 0")
            XCTAssertGreaterThan(desc.dpiMax, desc.dpiMin, "\(desc.codename): dpiMax must exceed dpiMin")
            XCTAssertLessThanOrEqual(desc.dpiMax, 32_000, "\(desc.codename): dpiMax > 32000 looks like a typo")
        }
    }
}
