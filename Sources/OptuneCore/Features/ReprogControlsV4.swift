import Foundation

/// HID++ 2.0 Feature `0x1B04` — Reprogrammable Controls V4.
///
/// Enumerates the buttons the firmware exposes (each identified by a 16-bit
/// **CID**) and reads/writes their reporting flags + diversion targets.
///
/// We expose the enumeration today; runtime remap (which routes button events
/// to host actions) happens in v0.4 once we have a CGEventTap + macOS
/// permissions story. This file is the read-only foundation: `optune buttons`
/// and the Settings UI use it to show users what their mouse can do.
public enum ReprogControlsV4Feature {
    public static let id: UInt16 = 0x1B04

    public struct Control: Sendable, Equatable, Hashable {
        public let index: UInt8
        public let cid: UInt16          // Control ID (e.g. 0x00C3 gesture button)
        public let taskID: UInt16       // Default task assigned by firmware
        public let flags: UInt8         // Bitfield: 0x10 reprogrammable, 0x08 fnSensitive, etc.
        public let position: UInt8      // Logical position (1-based, sometimes 0)
        public let group: UInt8
        public let groupMask: UInt8
        public let additionalFlags: UInt8

        public var isReprogrammable: Bool { (flags & 0x10) != 0 }
        public var isMouseButton: Bool { (flags & 0x01) != 0 }
        public var isFKey: Bool { (flags & 0x02) != 0 }
        public var isVirtual: Bool { (flags & 0x80) != 0 }
        public var supportsRawXY: Bool { (additionalFlags & 0x01) != 0 }

        /// Friendly description fed by `cid → button name` mapping.
        public var friendlyName: String {
            ButtonCatalog.name(for: cid) ?? String(format: "CID 0x%04X", cid)
        }
    }

    /// `function = 0x0` — getCount. Returns the number of programmable controls.
    public static func getCount(
        on transport: HIDPPTransport,
        featureIndex: UInt8
    ) async throws -> Int {
        let resp = try await transport.sendLong(featureIndex: featureIndex, function: 0x0)
        return Int(resp.params.first ?? 0)
    }

    /// `function = 0x1` — getControlInfo(index). Returns the metadata block.
    public static func getControlInfo(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        index: UInt8
    ) async throws -> Control {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x1,
            params: [index]
        )
        // Wire format: [cid_hi, cid_lo, task_hi, task_lo, flags, position, group, groupMask, addtFlags]
        guard resp.params.count >= 7 else { throw HIDPPError.invalidResponse }
        let cid = (UInt16(resp.params[0]) << 8) | UInt16(resp.params[1])
        let taskID = (UInt16(resp.params[2]) << 8) | UInt16(resp.params[3])
        let flags = resp.params[4]
        let position = resp.params[5]
        let group = resp.params[6]
        let groupMask = resp.params.count > 7 ? resp.params[7] : 0
        let addt = resp.params.count > 8 ? resp.params[8] : 0
        return Control(
            index: index,
            cid: cid,
            taskID: taskID,
            flags: flags,
            position: position,
            group: group,
            groupMask: groupMask,
            additionalFlags: addt
        )
    }

    /// Per-CID reporting/diversion settings managed by fn 0x2 (get) and fn 0x3 (set).
    public struct Reporting: Sendable, Equatable, Hashable {
        public let cid: UInt16
        /// True → events route over HID++ instead of native HID. Required for
        /// host-side remapping. Cleared on disconnect.
        public var diverted: Bool
        /// True → CID continues firing repeats while held (relevant for some buttons).
        public var persistentDivert: Bool
        /// True → "raw XY" reporting, only meaningful when control supports it.
        public var rawXYDiverted: Bool
        /// Optional remap CID — when nonzero the firmware reports this CID
        /// instead of its native one (host-side remap is the more flexible path).
        public var remap: UInt16

        public init(cid: UInt16, diverted: Bool = false, persistentDivert: Bool = false, rawXYDiverted: Bool = false, remap: UInt16 = 0) {
            self.cid = cid
            self.diverted = diverted
            self.persistentDivert = persistentDivert
            self.rawXYDiverted = rawXYDiverted
            self.remap = remap
        }
    }

    /// `function = 0x2` — getControlReporting(cid).
    /// Wire format response (long): `[cid_hi, cid_lo, flags, remap_hi, remap_lo, ...]`
    /// flags bits: 0x01 = persistentDiverted, 0x02 = diverted, 0x04 = rawXYDiverted.
    public static func getReporting(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        cid: UInt16
    ) async throws -> Reporting {
        let resp = try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x2,
            params: [UInt8(cid >> 8), UInt8(cid & 0xFF)]
        )
        guard resp.params.count >= 5 else { throw HIDPPError.invalidResponse }
        let flags = resp.params[2]
        let remap = (UInt16(resp.params[3]) << 8) | UInt16(resp.params[4])
        return Reporting(
            cid: cid,
            diverted: (flags & 0x02) != 0,
            persistentDivert: (flags & 0x01) != 0,
            rawXYDiverted: (flags & 0x04) != 0,
            remap: remap
        )
    }

    /// `function = 0x3` — setControlReporting(cid, flags, remap).
    /// Wire format request: `[cid_hi, cid_lo, flag_mask, remap_hi, remap_lo]`
    /// where bits we set match the get bitfield. The firmware ignores any bit
    /// it doesn't understand; the mask says which bits we mean.
    @discardableResult
    public static func setReporting(
        on transport: HIDPPTransport,
        featureIndex: UInt8,
        reporting: Reporting
    ) async throws -> HIDPPResponse {
        var flags: UInt8 = 0
        // Hi nibble = "change-mask" (which bits to apply).  Lo nibble = values.
        // We always set all three managed bits + remap (firmware is happy with
        // an "all bits authoritative" write; matches Solaar's pattern).
        let changeMask: UInt8 = 0xF0   // change persistent | diverted | rawXY | remap
        if reporting.persistentDivert { flags |= 0x01 }
        if reporting.diverted        { flags |= 0x02 }
        if reporting.rawXYDiverted   { flags |= 0x04 }
        let payload: [UInt8] = [
            UInt8(reporting.cid >> 8), UInt8(reporting.cid & 0xFF),
            changeMask | flags,
            UInt8(reporting.remap >> 8), UInt8(reporting.remap & 0xFF)
        ]
        return try await transport.sendLong(
            featureIndex: featureIndex,
            function: 0x3,
            params: payload
        )
    }

    /// Decode a hardware-initiated 0x1B04 notification.
    /// fn 0x0: button-down/up event, params = [cid_hi, cid_lo, ...].
    /// fn 0x1: raw XY event, params = [x_hi, x_lo, y_hi, y_lo, ...].
    /// We surface the button-press path here (gestures/remap consumer).
    public struct ButtonEvent: Sendable, Equatable {
        public let pressedCIDs: Set<UInt16>
    }

    public static func decodeButtonEvent(_ event: HIDPPResponse) -> ButtonEvent? {
        guard event.swID == 0, event.function == 0x0 else { return nil }
        var pressed: Set<UInt16> = []
        // The params contain up to 4 currently-pressed CIDs (16-bit big-endian).
        // 0x0000 = no button.
        let bytes = event.params
        var i = 0
        while i + 1 < bytes.count && i < 8 {
            let cid = (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])
            if cid != 0 { pressed.insert(cid) }
            i += 2
        }
        return ButtonEvent(pressedCIDs: pressed)
    }

    /// Walk Root → ReprogControlsV4 → enumerate every control. Capped at 32.
    public static func snapshot(
        on transport: HIDPPTransport,
        maxControls: Int = 32
    ) async throws -> [Control] {
        let lookup = try await RootFeature.getFeature(on: transport, featureID: id)
        guard lookup.isPresent else { return [] }
        let count = min(maxControls, try await getCount(on: transport, featureIndex: lookup.featureIndex))
        guard count > 0 else { return [] }
        var out: [Control] = []
        out.reserveCapacity(count)
        for i in 0..<UInt8(count) {
            do {
                let control = try await getControlInfo(
                    on: transport,
                    featureIndex: lookup.featureIndex,
                    index: i
                )
                out.append(control)
            } catch {
                // Skip individual control read failures; device may have a
                // sparse table or we hit a transient timeout.
                continue
            }
        }
        return out
    }
}

/// Friendly names for well-known Logitech control IDs.
/// Sourced from logiops/Solaar's `special_keys.py` — covers buttons that ship
/// on the MX Master family + common gesture/forward CIDs.
public enum ButtonCatalog {
    public static let names: [UInt16: String] = [
        0x0050: "Left Click",
        0x0051: "Right Click",
        0x0052: "Middle Click",
        0x0053: "Back",
        0x0056: "Forward",
        0x00B4: "App Switch",
        0x00C3: "Gesture Button",
        0x00C4: "Smart Shift Toggle",
        0x00D7: "Virtual Gesture Button",
        0x00DA: "DPI Switch (Cycle)",
        0x00DC: "DPI Up",
        0x00DD: "DPI Down",
        0x00DE: "DPI Toggle",
        0x00E0: "Mode Switch (Ratchet/Free)",
        0x00E7: "Switch Tracking Surface",
        0x00ED: "Multi-Platform Gesture Button",
        0x0157: "Tilt Right",
        0x0158: "Tilt Left",
        0x0159: "Side Button (Top)",
        0x015A: "Side Button (Bottom)"
    ]

    public static func name(for cid: UInt16) -> String? {
        names[cid]
    }
}
