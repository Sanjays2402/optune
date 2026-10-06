import Foundation

/// HID++ 2.0 Feature `0x8060` — Report Rate (USB/wireless polling interval).
///
/// Found on gaming mice (and some MX models). The device reports which polling
/// intervals it supports as a bitmask and lets the host pick one.
///
/// Function set on the wire:
/// - 0x0 → getReportRateList → `[mask]`, bit *i* set ⇒ the device supports an interval of *(i + 1)* ms
/// - 0x1 → getReportRate     → `[intervalMs]`
/// - 0x2 → setReportRate     → params `[intervalMs]`
public enum ReportRateFeature {
    public static let id: UInt16 = 0x8060

    public struct Status: Sendable, Equatable {
        /// Currently selected polling interval in milliseconds.
        public let currentMs: Int
        /// Supported polling intervals in milliseconds, ascending.
        public let supportedMs: [Int]

        public var currentHz: Int { ReportRateFeature.hertz(forIntervalMs: currentMs) }
        public var supportedHz: [Int] { supportedMs.map(ReportRateFeature.hertz(forIntervalMs:)).sorted() }
    }

    /// Decode the support bitmask into intervals (ms), ascending.
    public static func intervals(fromMask mask: UInt8) -> [Int] {
        (0..<8).filter { mask & (1 << $0) != 0 }.map { $0 + 1 }
    }

    /// 1 ms → 1000 Hz, 2 ms → 500 Hz, 3 ms → 333 Hz, …
    public static func hertz(forIntervalMs ms: Int) -> Int {
        ms > 0 ? Int((1000.0 / Double(ms)).rounded()) : 0
    }

    /// The supported interval whose frequency is closest to `hz`.
    public static func intervalMs(forHertz hz: Int, supported: [Int]) -> Int? {
        supported.min { abs(hertz(forIntervalMs: $0) - hz) < abs(hertz(forIntervalMs: $1) - hz) }
    }

    public static func getStatus(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Status {
        let list = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        guard let mask = list.params.first else { throw HIDPPError.invalidResponse }
        let cur = try await transport.sendLong(featureIndex: featureIndex, function: 0x1)
        guard let ms = cur.params.first else { throw HIDPPError.invalidResponse }
        return Status(currentMs: Int(ms), supportedMs: intervals(fromMask: mask))
    }

    @discardableResult
    public static func setInterval(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        ms: Int
    ) async throws -> HIDPPResponse {
        try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: [UInt8(max(1, min(8, ms)))]
        )
    }
}
