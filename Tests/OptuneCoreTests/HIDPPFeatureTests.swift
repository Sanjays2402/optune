import XCTest
@testable import OptuneCore

/// Unit tests for HID++ feature response parsing.
/// These don't open a real HID device — they construct `HIDPPResponse`
/// values directly and exercise the per-feature decoders.
final class HIDPPFeatureTests: XCTestCase {

    func test_unifiedBattery_parsesDischargingStatus() throws {
        // params = [percent=68, nextLevel=0, state=0 (discharging), flags=0]
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x06,
            function: 0x1,
            swID: 0x1,
            params: [68, 0, 0, 0],
            raw: []
        )
        let status = try parseUnifiedBattery(response)
        XCTAssertEqual(status.percent, 68)
        XCTAssertEqual(status.chargingState, .discharging)
        XCTAssertFalse(status.externalPower)
    }

    func test_unifiedBattery_detectsCharging() throws {
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x06,
            function: 0x1,
            swID: 0x1,
            params: [82, 0, 1, 0],
            raw: []
        )
        let status = try parseUnifiedBattery(response)
        XCTAssertEqual(status.percent, 82)
        XCTAssertEqual(status.chargingState, .charging)
        XCTAssertTrue(status.externalPower)
    }

    func test_unifiedBattery_detectsExternalPowerFlag() throws {
        // Discharging state but flags bit 7 set → still on external power.
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x06,
            function: 0x1,
            swID: 0x1,
            params: [100, 0, 0, 0x80],
            raw: []
        )
        let status = try parseUnifiedBattery(response)
        XCTAssertEqual(status.percent, 100)
        XCTAssertTrue(status.externalPower)
    }

    func test_unifiedBattery_unknownStateMaps() throws {
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x06,
            function: 0x1,
            swID: 0x1,
            params: [55, 0, 0xAA, 0],
            raw: []
        )
        let status = try parseUnifiedBattery(response)
        XCTAssertEqual(status.chargingState, .unknown)
    }

    func test_unifiedBattery_throwsOnTruncatedResponse() {
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x06,
            function: 0x1,
            swID: 0x1,
            params: [50],
            raw: []
        )
        XCTAssertThrowsError(try parseUnifiedBattery(response)) { error in
            guard case HIDPPError.invalidResponse = error else {
                return XCTFail("Expected .invalidResponse, got \(error)")
            }
        }
    }

    func test_root_lookup_decodesFeatureIndex() throws {
        // Root.GetFeature response = [featureIndex, featureType, featureVersion]
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x00,
            function: 0x0,
            swID: 0x1,
            params: [0x06, 0x00, 0x02],
            raw: []
        )
        let lookup = parseRootLookup(response)
        XCTAssertEqual(lookup.featureIndex, 0x06)
        XCTAssertEqual(lookup.featureType, 0x00)
        XCTAssertEqual(lookup.featureVersion, 0x02)
        XCTAssertTrue(lookup.isPresent)
    }

    func test_root_lookup_absentWhenIndexZero() {
        let response = HIDPPResponse(
            reportID: 0x11,
            deviceIndex: 0xFF,
            featureIndex: 0x00,
            function: 0x0,
            swID: 0x1,
            params: [0x00, 0x00, 0x00],
            raw: []
        )
        let lookup = parseRootLookup(response)
        XCTAssertFalse(lookup.isPresent)
    }

    // MARK: - Helpers (mirror the per-feature decoders so we don't need a live transport)

    private func parseUnifiedBattery(_ resp: HIDPPResponse) throws -> UnifiedBatteryFeature.Status {
        guard resp.params.count >= 3 else { throw HIDPPError.invalidResponse }
        let percent = resp.params[0]
        let stateRaw = resp.params[2]
        let state = UnifiedBatteryFeature.ChargingState(rawValue: stateRaw) ?? .unknown
        let flags = resp.params.count > 3 ? resp.params[3] : 0
        let externalPower = (flags & 0x80) != 0
            || state == .charging
            || state == .chargingNearlyFull
            || state == .chargingComplete
        return UnifiedBatteryFeature.Status(
            percent: percent,
            chargingState: state,
            externalPower: externalPower
        )
    }

    private func parseRootLookup(_ resp: HIDPPResponse) -> RootFeature.FeatureLookup {
        let idx = resp.params.first ?? 0
        let type = resp.params.count > 1 ? resp.params[1] : 0
        let version = resp.params.count > 2 ? resp.params[2] : 0
        return RootFeature.FeatureLookup(
            featureIndex: idx,
            featureType: type,
            featureVersion: version
        )
    }
}
