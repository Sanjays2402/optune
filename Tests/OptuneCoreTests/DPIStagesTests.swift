import XCTest
@testable import OptuneCore

final class DPIStagesTests: XCTestCase {
    func test_defaults_forMXMasterRange() {
        XCTAssertEqual(DPIStages.defaults(min: 200, max: 8000, step: 50), [800, 3200, 4100])
    }

    func test_normalize_snapsClampsDedupesSorts() {
        let out = DPIStages.normalize([3210, 790, 800, 99_999, 10], min: 200, max: 8000, step: 50)
        XCTAssertEqual(out, [200, 800, 3200, 8000])
    }

    func test_normalize_capsCount() {
        let out = DPIStages.normalize(Array(stride(from: 400, through: 4000, by: 400)), min: 200, max: 8000, step: 50)
        XCTAssertEqual(out.count, DPIStages.maxStages)
    }

    func test_next_wraps() {
        XCTAssertEqual(DPIStages.next(after: 800, in: [800, 1600, 3200]), 1600)
        XCTAssertEqual(DPIStages.next(after: 3200, in: [800, 1600, 3200]), 800)
        XCTAssertEqual(DPIStages.next(after: 1000, in: [3200, 800]), 3200)
        XCTAssertNil(DPIStages.next(after: 1000, in: []))
    }
}

final class DPIStagesPreviousTests: XCTestCase {
    func test_previous_wraps() {
        XCTAssertEqual(DPIStages.previous(before: 1600, in: [800, 1600, 3200]), 800)
        XCTAssertEqual(DPIStages.previous(before: 800, in: [800, 1600, 3200]), 3200)
        XCTAssertEqual(DPIStages.previous(before: 1000, in: [3200, 800]), 800)
        XCTAssertNil(DPIStages.previous(before: 1000, in: []))
    }

    func test_nextAndPreviousAreInverse() {
        let stages = [800, 1600, 3200, 4000]
        for s in stages {
            let n = DPIStages.next(after: s, in: stages)!
            XCTAssertEqual(DPIStages.previous(before: n, in: stages), s)
        }
    }
}
