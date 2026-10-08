import Foundation

/// Pure helpers for user-defined DPI stages (the values the cycle action and
/// the menu bar quick-switch rotate through).
public enum DPIStages {
    public static let maxStages = 6

    /// Sensible stages for a device's reported range: low / mid / high.
    public static func defaults(min lo: Int, max hi: Int, step: Int?) -> [Int] {
        normalize([max(lo, 800), (lo + hi) / 2, min(hi, 3200)], min: lo, max: hi, step: step)
    }

    /// Snap to the firmware step, clamp to range, drop duplicates, sort, and cap the count.
    public static func normalize(_ stages: [Int], min lo: Int, max hi: Int, step: Int?) -> [Int] {
        let s = Swift.max(step ?? 50, 50)
        let snapped = stages.map { value -> Int in
            let clamped = Swift.min(Swift.max(value, lo), hi)
            return Swift.min(Swift.max(((clamped + s / 2) / s) * s, lo), hi)
        }
        return Array(Set(snapped)).sorted().prefix(maxStages).map { $0 }
    }

    /// The first stage above `current`, wrapping to the lowest. Nil when there are no stages.
    public static func next(after current: Int, in stages: [Int]) -> Int? {
        let sorted = stages.sorted()
        return sorted.first { $0 > current } ?? sorted.first
    }

    /// The last stage below `current`, wrapping to the highest. Nil when there are no stages.
    public static func previous(before current: Int, in stages: [Int]) -> Int? {
        let sorted = stages.sorted()
        return sorted.last { $0 < current } ?? sorted.last
    }
}
