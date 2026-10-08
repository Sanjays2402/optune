import Foundation

/// Local diagnostic log. Lives only on this Mac, in `~/Library/Logs/Optune/`, and is never
/// uploaded anywhere. Serial numbers and nicknames registered via `protect(_:)` and the home
/// folder path are redacted before anything is written.
public enum OptuneLog {
    public enum Level: String, Sendable { case info = "INFO", warning = "WARN", error = "ERROR" }

    /// Rotate once the active file grows past this size; keep one previous file.
    public static let maxBytes = 512 * 1024

    private static let queue = DispatchQueue(label: "io.github.sanjays2402.optune.log")
    private static let lock = NSLock()
    private nonisolated(unsafe) static var sensitive: Set<String> = []
    private nonisolated(unsafe) static var overrideDirectory: URL?

    public static var directory: URL {
        if let overrideDirectory { return overrideDirectory }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Logs/Optune", isDirectory: true)
    }

    public static var fileURL: URL { directory.appendingPathComponent("optune.log") }

    /// Append one line. Returns immediately; writes happen on a background queue.
    public static func write(_ level: Level, _ category: String, _ message: String) {
        let line = "\(Date.now.formatted(.iso8601)) \(level.rawValue) [\(category)] \(redact(message))\n"
        queue.async { append(line) }
    }

    /// Mark a value (serial number, nickname…) so it is replaced with "[redacted]" in every line.
    public static func protect(_ value: String?) {
        guard let value, value.count >= 3 else { return }
        lock.lock(); defer { lock.unlock() }
        sensitive.insert(value)
    }

    /// Replace the home folder with "~" and any protected values with "[redacted]".
    public static func redact(_ text: String) -> String {
        lock.lock()
        let values = sensitive
        lock.unlock()
        var out = text.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        // Longest first so a value that contains another is replaced completely.
        for value in values.sorted(by: { $0.count > $1.count }) {
            out = out.replacingOccurrences(of: value, with: "[redacted]")
        }
        return out
    }

    /// The last `lines` lines of the active log (oldest first). Empty if there is no log yet.
    public static func tail(lines: Int = 200) -> String {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8) else { return "" }
            let all = text.split(separator: "\n", omittingEmptySubsequences: true)
            return all.suffix(lines).joined(separator: "\n")
        }
    }

    /// Delete the active log and its rotated copy.
    public static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: rotatedURL)
        }
    }

    /// Wait until queued writes have hit the disk (used by tests).
    public static func flush() { queue.sync {} }

    /// Redirect logging to another folder (tests only).
    public static func useDirectory(_ url: URL?) {
        queue.sync { overrideDirectory = url }
    }

    // MARK: - Private

    private static var rotatedURL: URL { directory.appendingPathComponent("optune.1.log") }

    private static func append(_ line: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let size = (try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        if size > maxBytes {
            try? fm.removeItem(at: rotatedURL)
            try? fm.moveItem(at: fileURL, to: rotatedURL)
        }
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL),
              let data = line.data(using: .utf8) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
