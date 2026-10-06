import XCTest
@testable import OptuneCore

final class ReportRateTests: XCTestCase {
    func test_intervals_fromMask() {
        XCTAssertEqual(ReportRateFeature.intervals(fromMask: 0b1000_1011), [1, 2, 4, 8])
        XCTAssertEqual(ReportRateFeature.intervals(fromMask: 0), [])
    }

    func test_hertz() {
        XCTAssertEqual(ReportRateFeature.hertz(forIntervalMs: 1), 1000)
        XCTAssertEqual(ReportRateFeature.hertz(forIntervalMs: 2), 500)
        XCTAssertEqual(ReportRateFeature.hertz(forIntervalMs: 3), 333)
        XCTAssertEqual(ReportRateFeature.hertz(forIntervalMs: 8), 125)
        XCTAssertEqual(ReportRateFeature.hertz(forIntervalMs: 0), 0)
    }

    func test_closestInterval() {
        XCTAssertEqual(ReportRateFeature.intervalMs(forHertz: 1000, supported: [1, 2, 4, 8]), 1)
        XCTAssertEqual(ReportRateFeature.intervalMs(forHertz: 300, supported: [1, 2, 4, 8]), 4)  // 250 Hz is closest
        XCTAssertNil(ReportRateFeature.intervalMs(forHertz: 500, supported: []))
    }
}
