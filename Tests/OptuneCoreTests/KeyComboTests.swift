import XCTest
@testable import OptuneCore

final class KeyComboTests: XCTestCase {
    func test_format_modifiersInMacOrder() {
        XCTAssertEqual(KeyCombo.format(keyCode: 40, modifiers: KeyCombo.command | KeyCombo.shift), "⇧⌘K")
        XCTAssertEqual(KeyCombo.format(keyCode: 2, modifiers: KeyCombo.control | KeyCombo.option), "⌃⌥D")
        XCTAssertEqual(KeyCombo.format(keyCode: 49, modifiers: 0), "Space")
        XCTAssertEqual(KeyCombo.format(keyCode: 126, modifiers: KeyCombo.command), "⌘↑")
    }

    func test_unknownKeyFallsBackToHex() {
        XCTAssertEqual(KeyCombo.format(keyCode: 0x7F, modifiers: KeyCombo.command), "⌘Key 0x7F")
    }

    func test_modifierMaskIgnoresOtherBits() {
        let raw: UInt64 = 0x100000 | 0x1 | 0x8000_0000   // command + stray device bits
        XCTAssertEqual(KeyCombo.modifierGlyphs(raw & KeyCombo.modifierMask), "⌘")
    }
}
