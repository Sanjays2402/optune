import XCTest
@testable import OptuneCore

final class BatteryInsightsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func sample(_ hours: Double, _ pct: Int, charging: Bool = false) -> BatterySample {
        BatterySample(timestamp: t0.addingTimeInterval(hours * 3600), percent: pct, charging: charging)
    }

    func test_drainRateAndRemaining_linearDischarge() {
        let s = [sample(0, 100), sample(5, 95), sample(10, 90)]   // 1 %/hr
        let i = BatteryInsights.analyze(s)
        XCTAssertEqual(i.drainPerHour ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(i.hoursRemaining ?? 0, 90, accuracy: 0.01)
    }

    func test_noEstimate_whenRunTooShortOrFlat() {
        XCTAssertNil(BatteryInsights.analyze([sample(0, 80), sample(0.1, 79)]).drainPerHour)
        XCTAssertNil(BatteryInsights.analyze([sample(0, 80), sample(5, 80)]).drainPerHour)
        XCTAssertNil(BatteryInsights.analyze([]).drainPerHour)
    }

    func test_chargingResetsRun_andCountsSessions() {
        let s = [sample(0, 50), sample(1, 40),
                 sample(2, 45, charging: true), sample(3, 90, charging: true),
                 sample(4, 90), sample(14, 80)]
        let i = BatteryInsights.analyze(s)
        XCTAssertEqual(i.chargeSessions, 1)
        XCTAssertEqual(i.lastChargedAt, t0.addingTimeInterval(3 * 3600))
        XCTAssertEqual(i.drainPerHour ?? 0, 1.0, accuracy: 0.001)
    }

    func test_policy_collapsesDuplicatesAndPrunes() {
        var h: [BatterySample] = []
        h = BatteryHistoryPolicy.appending(sample(0, 90), to: h)
        h = BatteryHistoryPolicy.appending(sample(0.05, 90), to: h)   // <10 min, same → dropped
        h = BatteryHistoryPolicy.appending(sample(0.1, 89), to: h)
        XCTAssertEqual(h.count, 2)
        h = BatteryHistoryPolicy.appending(sample(15 * 24, 80), to: h) // 15 days later
        XCTAssertEqual(h.count, 1)
    }

    func test_formatRemaining() {
        XCTAssertEqual(BatteryInsights.formatRemaining(hours: 72), "~3 days")
        XCTAssertEqual(BatteryInsights.formatRemaining(hours: 14.2), "~14 hr")
        XCTAssertEqual(BatteryInsights.formatRemaining(hours: 0.5), "~30 min")
    }
}
