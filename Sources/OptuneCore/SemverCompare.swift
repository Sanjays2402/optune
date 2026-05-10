import Foundation

/// Numeric-only semver compare used by the update checker.
///
/// Strips a leading `v`/`V`, drops pre-release (`-rc1`) and build (`+sha.abc`)
/// suffixes, then compares the major/minor/patch components as integers.
/// A bare release outranks any pre-release with the same numeric core
/// (per [SemVer §11](https://semver.org/#spec-item-11)).
public enum SemverCompare {

    /// Returns `true` iff `a > b`.
    public static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let av = numericComponents(a)
        let bv = numericComponents(b)
        let n = Swift.max(av.count, bv.count)
        for i in 0..<n {
            let lhs = i < av.count ? av[i] : 0
            let rhs = i < bv.count ? bv[i] : 0
            if lhs > rhs { return true }
            if lhs < rhs { return false }
        }
        // Equal numeric core: a release outranks a pre-release.
        let aIsPre = a.contains("-")
        let bIsPre = b.contains("-")
        if !aIsPre && bIsPre { return true }
        return false
    }

    /// Strip leading `v`, pre-release, and build metadata; split the rest by `.`.
    public static func numericComponents(_ raw: String) -> [Int] {
        var s = raw
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let dash = s.firstIndex(of: "-") { s = String(s[..<dash]) }
        if let plus = s.firstIndex(of: "+") { s = String(s[..<plus]) }
        return s.split(separator: ".").map { Int($0) ?? 0 }
    }
}
