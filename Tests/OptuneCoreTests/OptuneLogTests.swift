import XCTest
@testable import OptuneCore

final class OptuneLogTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        OptuneLog.useDirectory(dir)
    }

    override func tearDown() {
        OptuneLog.flush()
        OptuneLog.useDirectory(nil)
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func test_redact_replacesProtectedValuesAndHomePath() {
        OptuneLog.protect("31A5D392")
        OptuneLog.protect("Sanjay's MX")
        let out = OptuneLog.redact("serial 31A5D392 for Sanjay's MX at \(NSHomeDirectory())/x")
        XCTAssertEqual(out, "serial [redacted] for [redacted] at ~/x")
    }

    func test_shortValuesAreNotProtected() {
        OptuneLog.protect("ab")   // too short to be safe to replace
        XCTAssertEqual(OptuneLog.redact("ab cd"), "ab cd")
    }

    func test_writeThenTail() {
        OptuneLog.write(.info, "test", "first")
        OptuneLog.write(.warning, "test", "second")
        OptuneLog.flush()
        let tail = OptuneLog.tail(lines: 10)
        XCTAssertTrue(tail.contains("INFO [test] first"))
        XCTAssertTrue(tail.hasSuffix("WARN [test] second"))
    }

    func test_tailKeepsOnlyLastLines() {
        for i in 0..<20 { OptuneLog.write(.info, "n", "line \(i)") }
        OptuneLog.flush()
        let lines = OptuneLog.tail(lines: 3).split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines.last!.hasSuffix("line 19"))
    }

    func test_clearRemovesFile() {
        OptuneLog.write(.error, "test", "boom")
        OptuneLog.flush()
        OptuneLog.clear()
        OptuneLog.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: OptuneLog.fileURL.path))
    }
}
