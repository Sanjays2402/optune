import Foundation

/// A single battery reading persisted for trend and drain analysis.
public struct BatterySample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let percent: Int
    public let charging: Bool

    public init(timestamp: Date, percent: Int, charging: Bool) {
        self.timestamp = timestamp
        self.percent = percent
        self.charging = charging
    }
}

/// Retention rules for the on-disk battery history.
public enum BatteryHistoryPolicy {
    /// Samples older than this are dropped.
    public static let maxAge: TimeInterval = 14 * 24 * 3600
    /// Hard cap so the settings file stays small.
    public static let maxSamples = 2000
    /// An unchanged reading is only re-recorded after this long.
    public static let minInterval: TimeInterval = 10 * 60

    /// Append `sample` to `history`, collapsing unchanged readings and
    /// pruning by age and count. Returns the new history (newest last).
    public static func appending(_ sample: BatterySample, to history: [BatterySample]) -> [BatterySample] {
        var out = history
        if let last = out.last,
           last.percent == sample.percent,
           last.charging == sample.charging,
           sample.timestamp.timeIntervalSince(last.timestamp) < minInterval {
            return out
        }
        out.append(sample)
        let cutoff = sample.timestamp.addingTimeInterval(-maxAge)
        if let firstKept = out.firstIndex(where: { $0.timestamp >= cutoff }), firstKept > 0 {
            out.removeFirst(firstKept)
        }
        if out.count > maxSamples { out.removeFirst(out.count - maxSamples) }
        return out
    }
}

/// Derived statistics for a device's battery history.
public struct BatteryInsights: Equatable, Sendable {
    /// Average drain over the current discharge run, in percentage points per hour.
    public let drainPerHour: Double?
    /// Estimated hours until empty at the current drain rate.
    public let hoursRemaining: Double?
    /// When the battery was last seen at (or near) full, or when charging last ended.
    public let lastChargedAt: Date?
    /// Number of distinct charging sessions in the history.
    public let chargeSessions: Int

    /// Minimum span and drop before we trust a drain estimate.
    static let minRunSeconds: TimeInterval = 30 * 60
    static let minDropPercent = 2

    public static func analyze(_ samples: [BatterySample]) -> BatteryInsights {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        var sessions = 0
        var wasCharging = false
        var lastChargedAt: Date?
        for s in sorted {
            if s.charging {
                if !wasCharging { sessions += 1 }
                lastChargedAt = s.timestamp
            }
            wasCharging = s.charging
        }

        // Current discharge run: everything after the latest charging sample,
        // also split at any upward jump (charged while unplugged readings, e.g. battery swap).
        var run: [BatterySample] = []
        for s in sorted {
            if s.charging { run = []; continue }
            if let prev = run.last, s.percent > prev.percent + 1 { run = [] }
            run.append(s)
        }

        var rate: Double?
        var remaining: Double?
        if let first = run.first, let last = run.last,
           last.timestamp.timeIntervalSince(first.timestamp) >= minRunSeconds,
           first.percent - last.percent >= minDropPercent,
           let slope = slopePerHour(run), slope > 0 {
            rate = slope
            remaining = Double(last.percent) / slope
        }

        return BatteryInsights(
            drainPerHour: rate,
            hoursRemaining: remaining,
            lastChargedAt: lastChargedAt,
            chargeSessions: sessions
        )
    }

    /// Least-squares drain (percentage points lost per hour) over `run`.
    private static func slopePerHour(_ run: [BatterySample]) -> Double? {
        guard run.count >= 2, let t0 = run.first?.timestamp else { return nil }
        let xs = run.map { $0.timestamp.timeIntervalSince(t0) / 3600 }
        let ys = run.map { Double($0.percent) }
        let n = Double(run.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        let denom = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard denom > 0 else { return nil }
        let num = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return -(num / denom)
    }

    /// Human-readable estimate, e.g. "~3 days", "~14 hr", "~40 min".
    public static func formatRemaining(hours: Double) -> String {
        if hours >= 48 { return "~\(Int((hours / 24).rounded())) days" }
        if hours >= 1 { return "~\(Int(hours.rounded())) hr" }
        return "~\(max(1, Int((hours * 60).rounded()))) min"
    }
}
