import XCTest
@testable import OptuneCore

final class URLCommandTests: XCTestCase {
    private func parse(_ s: String) -> URLCommand? { URL(string: s).flatMap(URLCommand.parse) }

    func test_valid() {
        XCTAssertEqual(parse("optune://dpi/1600"), .dpi(1600))
        XCTAssertEqual(parse("optune://dpi/next"), .dpiNext)
        XCTAssertEqual(parse("optune://dpi/prev"), .dpiPrevious)
        XCTAssertEqual(parse("optune://host/2"), .host(2))
        XCTAssertEqual(parse("optune://smartshift/toggle"), .smartShift(.toggle))
        XCTAssertEqual(parse("optune://scroll/freespin"), .scroll(.freespin))
        XCTAssertEqual(parse("optune://rate/1000"), .reportRate(1000))
        XCTAssertEqual(parse("OPTUNE://DPI/800"), .dpi(800))
    }

    func test_rejects_badInput() {
        XCTAssertNil(parse("optune://dpi/50"))          // below range
        XCTAssertNil(parse("optune://dpi/999999"))      // above range
        XCTAssertNil(parse("optune://host/0"))
        XCTAssertNil(parse("optune://host/4"))
        XCTAssertNil(parse("optune://smartshift/maybe"))
        XCTAssertNil(parse("optune://dpi"))             // missing argument
        XCTAssertNil(parse("optune://dpi/1600/extra"))  // too many components
        XCTAssertNil(parse("optune://shell/rm"))        // unknown action
        XCTAssertNil(parse("https://dpi/1600"))         // wrong scheme
    }
}
