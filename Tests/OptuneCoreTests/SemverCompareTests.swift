import XCTest
@testable import OptuneCore

final class SemverCompareTests: XCTestCase {

    func testReleaseOverPrerelease() {
        // SemVer §11: 1.0.0 > 1.0.0-rc1
        XCTAssertTrue(SemverCompare.isVersion("0.6.0", newerThan: "0.6.0-rc1"))
        XCTAssertFalse(SemverCompare.isVersion("0.6.0-rc1", newerThan: "0.6.0"))
    }

    func testNumericPrecedence() {
        XCTAssertTrue(SemverCompare.isVersion("1.2.3", newerThan: "1.2.0"))
        XCTAssertTrue(SemverCompare.isVersion("1.2.3", newerThan: "1.1.99"))
        XCTAssertTrue(SemverCompare.isVersion("2.0.0", newerThan: "1.99.99"))
    }

    func testEqualReturnsFalse() {
        XCTAssertFalse(SemverCompare.isVersion("0.6.0", newerThan: "0.6.0"))
        XCTAssertFalse(SemverCompare.isVersion("v0.6.0", newerThan: "0.6.0"))
    }

    func testStripsLeadingV() {
        XCTAssertTrue(SemverCompare.isVersion("v0.6.1", newerThan: "v0.6.0"))
        XCTAssertTrue(SemverCompare.isVersion("V1.0.0", newerThan: "0.99.99"))
    }

    func testStripsBuildMetadata() {
        // 1.2.3+sha.abc and 1.2.3 compare equal on numeric core; neither is pre-release.
        XCTAssertFalse(SemverCompare.isVersion("1.2.3+sha.abc", newerThan: "1.2.3"))
        XCTAssertFalse(SemverCompare.isVersion("1.2.3", newerThan: "1.2.3+sha.abc"))
    }

    func testShortVersions() {
        // Missing patch segment treated as 0.
        XCTAssertTrue(SemverCompare.isVersion("1.1", newerThan: "1.0.99"))
        XCTAssertFalse(SemverCompare.isVersion("1.0", newerThan: "1.0.0"))
    }

    func testGarbageSegmentsTreatedAsZero() {
        XCTAssertFalse(SemverCompare.isVersion("1.x.0", newerThan: "1.0.0"))
        XCTAssertTrue(SemverCompare.isVersion("1.0.1", newerThan: "1.x.0"))
    }

    func testNumericComponentsStrips() {
        XCTAssertEqual(SemverCompare.numericComponents("v1.2.3"), [1, 2, 3])
        XCTAssertEqual(SemverCompare.numericComponents("1.2.3-rc1"), [1, 2, 3])
        XCTAssertEqual(SemverCompare.numericComponents("1.2.3+sha.abc"), [1, 2, 3])
        XCTAssertEqual(SemverCompare.numericComponents("v1.2.3-rc1+sha.abc"), [1, 2, 3])
    }
}
