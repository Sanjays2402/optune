import Foundation

/// HID++ 2.0 Feature `0x2201` — Adjustable DPI.
///
/// Reads the device's current DPI, the supported DPI list (some devices return
/// a stepped list `[200, 400, 800, ...]`, others a `(min, step, max)` triple
/// encoded as `[min_hi, min_lo, 0xE0|step_hi, step_lo, max_hi, max_lo]`) and
/// pushes a new DPI down the wire. We expose both the raw list and a normalized
/// `(min, max)` pair for slider UIs.
public enum AdjustableDPIFeature {
    public static let id: UInt16 = 0x2201

    public struct DPIRange: Sendable, Equatable {
        public let min: Int
        public let max: Int
        public let step: Int?           // present when device returned a (min,step,max) triple
        public let presets: [Int]       // present when device returned an explicit list

        public var isStepped: Bool { step != nil }
    }

    public struct Status: Sendable, Equatable {
        public let sensorIndex: UInt8
        public let currentDPI: Int
        public let defaultDPI: Int?
        public let range: DPIRange
    }

    /// `function = 0x0` — getSensorCount. Most Logitech mice expose exactly one sensor.
    public static func getSensorCount(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Int {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x0
        )
        return Int(resp.params.first ?? 1)
    }

    /// `function = 0x1` — getSensorDPIList(sensorIdx).
    /// Returns the device's supported DPI values OR a stepped range.
    public static func getDPIList(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        sensorIndex: UInt8 = 0
    ) async throws -> DPIRange {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [sensorIndex]
        )
        return parseRange(params: resp.params)
    }

    /// `function = 0x2` — getSensorDPI(sensorIdx).
    /// Returns `(currentDPI, defaultDPI?)`. Default DPI is firmware-configured
    /// and present on most modern MX-family mice.
    public static func getDPI(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        sensorIndex: UInt8 = 0
    ) async throws -> (current: Int, defaultDPI: Int?) {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: [sensorIndex]
        )
        // Wire format: [sensorIdx][cur_hi][cur_lo][def_hi][def_lo]
        guard resp.params.count >= 3 else { throw HIDPPError.invalidResponse }
        let current = (Int(resp.params[1]) << 8) | Int(resp.params[2])
        var defaultDPI: Int?
        if resp.params.count >= 5 {
            let raw = (Int(resp.params[3]) << 8) | Int(resp.params[4])
            defaultDPI = raw == 0 ? nil : raw
        }
        return (current, defaultDPI)
    }

    /// `function = 0x3` — setSensorDPI(sensorIdx, dpi). Returns the DPI the device
    /// actually applied (firmware silently clamps to the supported range).
    @discardableResult
    public static func setDPI(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        dpi: Int,
        sensorIndex: UInt8 = 0
    ) async throws -> Int {
        let value = max(0, min(0xFFFF, dpi))
        let hi = UInt8((value >> 8) & 0xFF)
        let lo = UInt8(value & 0xFF)
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x3,
            params: [sensorIndex, hi, lo]
        )
        guard resp.params.count >= 3 else { throw HIDPPError.invalidResponse }
        return (Int(resp.params[1]) << 8) | Int(resp.params[2])
    }

    /// One-shot helper that walks Root → AdjustableDPI → readSnapshot for a
    /// single sensor. UI-friendly: returns everything needed to render a slider.
    public static func snapshot(
        on transport: HIDPPTransport
    ) async throws -> Status {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { throw HIDPPError.invalidResponse }
        let range = try await getDPIList(on: transport, featureIndex: lookup.featureIndex)
        let (current, fallback) = try await getDPI(on: transport, featureIndex: lookup.featureIndex)
        return Status(
            sensorIndex: 0,
            currentDPI: current,
            defaultDPI: fallback,
            range: range
        )
    }

    // MARK: - Parser

    /// Parse the DPI list payload. Logitech encodes ranges in two ways:
    ///
    /// - **Explicit list:** `[hi1, lo1, hi2, lo2, ...]` 16-bit BE values, terminated by 0x0000.
    /// - **Stepped range:** one entry has the high bit set on `hi` (0xE0 marker) — the byte
    ///   before is the min, the byte after is the max. Layout: `[min_hi, min_lo, 0xE0|step_hi, step_lo, max_hi, max_lo]`.
    static func parseRange(params: [UInt8]) -> DPIRange {
        // Drop the leading sensor index byte if present (firmware echoes it back).
        let body = Array(params.drop(while: { $0 == 0 }))
        var presets: [Int] = []
        var i = 0
        var stepMarkerIndex: Int?
        while i + 1 < body.count {
            let hi = body[i]
            let lo = body[i + 1]
            if hi == 0 && lo == 0 { break }
            if (hi & 0xE0) == 0xE0 {
                // Stepped marker. The 13 LSB encode the step value.
                stepMarkerIndex = presets.count
                let stepValue = ((Int(hi) & 0x1F) << 8) | Int(lo)
                presets.append(-stepValue)   // sentinel: negative = step
            } else {
                presets.append((Int(hi) << 8) | Int(lo))
            }
            i += 2
        }

        if let markerAt = stepMarkerIndex,
           markerAt > 0,
           markerAt + 1 < presets.count
        {
            let minVal = presets[markerAt - 1]
            let stepVal = -presets[markerAt]
            let maxVal = presets[markerAt + 1]
            return DPIRange(min: minVal, max: maxVal, step: stepVal, presets: [])
        }

        let positives = presets.filter { $0 > 0 }.sorted()
        let lo = positives.first ?? 200
        let hi = positives.last ?? 8000
        return DPIRange(min: lo, max: hi, step: nil, presets: positives)
    }
}
