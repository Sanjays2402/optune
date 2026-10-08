import Foundation

/// Names and formatting for keyboard shortcuts (macOS virtual key codes + modifier flags).
public enum KeyCombo {
    // Same bit values as CGEventFlags / NSEvent.ModifierFlags device-independent flags.
    public static let shift: UInt64 = 0x20000
    public static let control: UInt64 = 0x40000
    public static let option: UInt64 = 0x80000
    public static let command: UInt64 = 0x100000
    public static let modifierMask: UInt64 = shift | control | option | command

    /// Modifier glyphs in the conventional macOS order: ⌃⌥⇧⌘.
    public static func modifierGlyphs(_ modifiers: UInt64) -> String {
        var out = ""
        if modifiers & control != 0 { out += "⌃" }
        if modifiers & option != 0 { out += "⌥" }
        if modifiers & shift != 0 { out += "⇧" }
        if modifiers & command != 0 { out += "⌘" }
        return out
    }

    /// Display name of a key on a US layout; nil for codes we don't know.
    public static func keyName(_ code: Int) -> String? { names[code] }

    /// e.g. `format(keyCode: 40, modifiers: command | shift)` → "⇧⌘K".
    public static func format(keyCode: Int, modifiers: UInt64) -> String {
        let key = keyName(keyCode) ?? "Key 0x" + String(keyCode, radix: 16, uppercase: true)
        return modifierGlyphs(modifiers) + key
    }

    private static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10",
        111: "F12", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
