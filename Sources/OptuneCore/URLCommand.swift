import Foundation

/// Commands accepted over the `optune://` URL scheme (Shortcuts "Open URL", scripts, `open`).
///
///     optune://dpi/1600          optune://dpi/next
///     optune://host/2            (1-based Easy-Switch slot)
///     optune://smartshift/on|off|toggle
///     optune://scroll/ratchet|freespin|toggle
///     optune://rate/1000
public enum URLCommand: Equatable, Sendable {
    public enum Switch: String, Sendable { case on, off, toggle }
    public enum ScrollMode: String, Sendable { case ratchet, freespin, toggle }

    case dpi(Int)
    case dpiNext
    case host(Int)
    case smartShift(Switch)
    case scroll(ScrollMode)
    case reportRate(Int)

    public static let scheme = "optune"

    /// Parse a URL; nil for anything unrecognised or out of range.
    public static func parse(_ url: URL) -> URLCommand? {
        guard url.scheme?.lowercased() == scheme, let action = url.host?.lowercased() else { return nil }
        let args = url.pathComponents.filter { $0 != "/" }.map { $0.lowercased() }
        guard args.count == 1, let arg = args.first else { return nil }

        switch action {
        case "dpi":
            if arg == "next" { return .dpiNext }
            if let n = Int(arg), (100...32_000).contains(n) { return .dpi(n) }
        case "host":
            if let n = Int(arg), (1...3).contains(n) { return .host(n) }
        case "smartshift":
            if let s = Switch(rawValue: arg) { return .smartShift(s) }
        case "scroll":
            if let m = ScrollMode(rawValue: arg) { return .scroll(m) }
        case "rate":
            if let n = Int(arg), (125...8_000).contains(n) { return .reportRate(n) }
        default:
            break
        }
        return nil
    }
}
