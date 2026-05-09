import Foundation

/// Top-level Optune version + identifying info — pinned in one place so
/// the CLI, app, and packaging metadata stay in sync.
public enum Optune {
    public static let version: String = "0.1.0"
    public static let bundleIdentifier: String = "com.sanjays2402.optune"
    public static let projectURL: String = "https://github.com/Sanjays2402/optune"
}
