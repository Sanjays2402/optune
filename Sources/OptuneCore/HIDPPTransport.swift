import Foundation
import IOKit
import IOKit.hid

/// One HID++ 2.0 response received from the device.
///
/// Wire format (HID++ 2.0):
/// ```
/// [report_id][device_index][feature_index][func<<4 | swid][params...]
/// ```
/// `feature_index == 0xFF` flags an error reply; the failing call is encoded
/// in the next bytes. We do not try to decode HID++ 1.0 here.
public struct HIDPPResponse: Sendable, Equatable {
    public let reportID: UInt8
    public let deviceIndex: UInt8
    public let featureIndex: UInt8
    public let function: UInt8
    public let swID: UInt8
    public let params: [UInt8]
    public let raw: [UInt8]

    public var isError: Bool { featureIndex == 0xFF }

    /// Best-effort error code when `isError` is true.
    /// HID++ 2.0 error frame: `[reportID][devIdx][0xFF][failedFeatureIdx<<4|swID][failedFn][errorCode]`
    public var errorCode: UInt8? {
        guard isError, raw.count >= 6 else { return nil }
        return raw[5]
    }
}

/// Errors produced by the HID++ transport layer.
public enum HIDPPError: Error, CustomStringConvertible, Sendable {
    case deviceNotFound
    case openFailed(IOReturn)
    case sendFailed(IOReturn)
    case timeout
    case invalidResponse
    case errorResponse(featureIndex: UInt8, function: UInt8, errorCode: UInt8)
    case noFreeSoftwareID
    case closed

    public var description: String {
        switch self {
        case .deviceNotFound:
            return "Device not found in IOKit registry"
        case .openFailed(let r):
            return "IOHIDDeviceOpen failed (IOReturn=\(String(format: "0x%08X", r)))"
        case .sendFailed(let r):
            return "IOHIDDeviceSetReport failed (IOReturn=\(String(format: "0x%08X", r)))"
        case .timeout:
            return "Timed out waiting for HID++ response"
        case .invalidResponse:
            return "Invalid or short HID++ response"
        case .errorResponse(let f, let fn, let code):
            return "HID++ error: feature=0x\(String(f, radix: 16)) fn=0x\(String(fn, radix: 16)) code=0x\(String(code, radix: 16))"
        case .noFreeSoftwareID:
            return "All HID++ software-IDs in use; cannot send another request"
        case .closed:
            return "Transport is closed"
        }
    }
}

/// HID++ 2.0 transport over a single Logitech IOHIDDevice.
///
/// Send requests with `sendShort`/`sendLong`; the call awaits the matching
/// response correlated by software-ID (low nibble of byte 3 in the request).
/// Direct-paired devices (Bolt/Unifying paired or BLE) use `deviceIndex = 0xFF`.
///
/// Concurrency: state is guarded by a serial dispatch queue, and the IOHIDDevice
/// input callback re-enters that queue. This class is `@unchecked Sendable`.
public final class HIDPPTransport: @unchecked Sendable {

    private let device: IOHIDDevice
    private let queue = DispatchQueue(label: "io.github.sanjays2402.optune.hidpp", qos: .userInitiated)
    private var inputBuffer: UnsafeMutablePointer<UInt8>
    private let inputBufferSize: CFIndex

    /// Pending continuations keyed by software-ID (1...15; 0 is reserved for hardware events).
    private var pending: [UInt8: CheckedContinuation<HIDPPResponse, Error>] = [:]
    private var nextSWID: UInt8 = 1
    private var isOpen = false
    private var deviceIndex: UInt8 = 0xFF

    /// Open the underlying IOHIDDevice and start input-report scheduling on the main run loop.
    public init(matching device: LogitechDevice) throws {
        guard let hidDevice = HIDPPTransport.findIOHIDDevice(matching: device) else {
            throw HIDPPError.deviceNotFound
        }
        self.device = hidDevice
        self.inputBufferSize = 64
        self.inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        self.inputBuffer.initialize(repeating: 0, count: 64)

        let openResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            inputBuffer.deallocate()
            throw HIDPPError.openFailed(openResult)
        }
        isOpen = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            hidDevice,
            inputBuffer,
            inputBufferSize,
            HIDPPTransport.inputReportCallback,
            context
        )
        // Use dispatch queue (works in CLI w/o active CFRunLoop).
        IOHIDDeviceSetDispatchQueue(hidDevice, queue)
        IOHIDDeviceActivate(hidDevice)
    }

    deinit {
        close()
        inputBuffer.deallocate()
    }

    public func close() {
        queue.sync {
            guard isOpen else { return }
            isOpen = false
            // Cancel scheduled queue dispatch — IOKit handles callback teardown.
            // Do NOT call IOHIDDeviceRegisterInputReportCallback(..., nil, nil) here:
            // after IOHIDDeviceActivate, the callback is owned by the dispatch queue
            // and explicit deregister crashes inside IOKit.
            IOHIDDeviceCancel(device)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            // Fail any pending requests so callers don't hang.
            for (_, cont) in pending { cont.resume(throwing: HIDPPError.closed) }
            pending.removeAll()
        }
    }

    /// Send a 7-byte HID++ short request and await the correlated response.
    public func sendShort(
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8] = [],
        timeout: TimeInterval = 1.0
    ) async throws -> HIDPPResponse {
        try await send(
            reportID: HIDPP.reportShort,
            featureIndex: featureIndex,
            function: function,
            params: params,
            payloadSize: 6,
            timeout: timeout
        )
    }

    /// Send a 20-byte HID++ long request and await the correlated response.
    public func sendLong(
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8] = [],
        timeout: TimeInterval = 1.0
    ) async throws -> HIDPPResponse {
        try await send(
            reportID: HIDPP.reportLong,
            featureIndex: featureIndex,
            function: function,
            params: params,
            payloadSize: 19,
            timeout: timeout
        )
    }

    private func send(
        reportID: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8],
        payloadSize: Int,
        timeout: TimeInterval
    ) async throws -> HIDPPResponse {
        // Allocate sw-id, register continuation, then issue setReport.
        // We wrap in withCheckedThrowingContinuation; the runloop callback resumes us.
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HIDPPResponse, Error>) in
            queue.async { [self] in
                guard isOpen else {
                    continuation.resume(throwing: HIDPPError.closed)
                    return
                }
                guard let swID = allocateSWID() else {
                    continuation.resume(throwing: HIDPPError.noFreeSoftwareID)
                    return
                }
                pending[swID] = continuation

                // Build payload: [devIdx][featureIdx][fn<<4|swid][params padded to size]
                var payload = [UInt8](repeating: 0, count: payloadSize)
                payload[0] = deviceIndex
                payload[1] = featureIndex
                payload[2] = (function << 4) | (swID & 0x0F)
                for (i, b) in params.prefix(payloadSize - 3).enumerated() {
                    payload[3 + i] = b
                }

                // IOHIDDeviceSetReport sends Output reports with the given report ID.
                let result = payload.withUnsafeBufferPointer { buf -> IOReturn in
                    IOHIDDeviceSetReport(
                        device,
                        kIOHIDReportTypeOutput,
                        CFIndex(reportID),
                        buf.baseAddress!,
                        CFIndex(payload.count)
                    )
                }
                if ProcessInfo.processInfo.environment["OPTUNE_HIDPP_DEBUG"] != nil {
                    let hex = ([reportID] + payload).map { String(format: "%02X", $0) }.joined(separator: " ")
                    FileHandle.standardError.write(Data("[hidpp tx] \(hex)  result=\(String(format: "0x%08X", result))\n".utf8))
                }
                if result != kIOReturnSuccess {
                    pending.removeValue(forKey: swID)
                    continuation.resume(throwing: HIDPPError.sendFailed(result))
                    return
                }

                // Schedule timeout on the same queue.
                queue.asyncAfter(deadline: .now() + timeout) { [self] in
                    if let cont = pending.removeValue(forKey: swID) {
                        cont.resume(throwing: HIDPPError.timeout)
                    }
                }
            }
        }
    }

    private func allocateSWID() -> UInt8? {
        // Allocate the next free sw-id in 1...15 (skip 0 — reserved for HW events).
        for _ in 1...15 {
            let candidate = nextSWID
            nextSWID = nextSWID == 15 ? 1 : nextSWID + 1
            if pending[candidate] == nil { return candidate }
        }
        return nil
    }

    // MARK: - IOHID callback

    private static let inputReportCallback: IOHIDReportCallback = { context, _, _, _, reportID, report, length in
        guard let context = context else { return }
        let me = Unmanaged<HIDPPTransport>.fromOpaque(context).takeUnretainedValue()
        var bytes = [UInt8](repeating: 0, count: Int(length))
        for i in 0..<Int(length) { bytes[i] = report[i] }
        // IOKit strips report ID into a separate parameter on macOS; reattach for parsing.
        var full = [UInt8(reportID)] + bytes
        // Some macOS versions DO include the report ID in `report`. Detect duplicate header.
        if bytes.first == UInt8(reportID) { full = bytes }
        if ProcessInfo.processInfo.environment["OPTUNE_HIDPP_DEBUG"] != nil {
            let hex = full.map { String(format: "%02X", $0) }.joined(separator: " ")
            FileHandle.standardError.write(Data("[hidpp rx] \(hex)\n".utf8))
        }
        me.handleIncoming(full)
    }

    private func handleIncoming(_ raw: [UInt8]) {
        // Minimum HID++ frame is 4 bytes: reportID, devIdx, featureIdx, fn|swid.
        guard raw.count >= 4 else { return }
        let reportID = raw[0]
        guard reportID == HIDPP.reportShort || reportID == HIDPP.reportLong else { return }

        let devIdx = raw[1]
        let featureIdx = raw[2]
        let fnByte = raw[3]
        let function = (fnByte >> 4) & 0x0F
        let swID = fnByte & 0x0F
        let params = Array(raw.dropFirst(4))

        // sw-id 0 means hardware-initiated event (battery alert, etc.) — drop for now.
        guard swID != 0 else { return }

        queue.async { [self] in
            guard let cont = pending.removeValue(forKey: swID) else { return }
            // Error frame: featureIdx == 0xFF, payload encodes [failedFeatureIdx][failedFn][errorCode]
            if featureIdx == 0xFF, raw.count >= 7 {
                let failedFeature = raw[4]
                let failedFn = raw[5]
                let errCode = raw[6]
                cont.resume(throwing: HIDPPError.errorResponse(
                    featureIndex: failedFeature, function: failedFn, errorCode: errCode))
                return
            }
            let response = HIDPPResponse(
                reportID: reportID,
                deviceIndex: devIdx,
                featureIndex: featureIdx,
                function: function,
                swID: swID,
                params: params,
                raw: raw
            )
            cont.resume(returning: response)
        }
    }

    // MARK: - Device discovery

    /// Look up the underlying IOHIDDevice for a `LogitechDevice` discovered via
    /// `HIDEnumerator`. We re-enumerate (rather than retain refs in the value
    /// type) to keep `LogitechDevice` `Sendable` and free of IOKit handles.
    private static func findIOHIDDevice(matching wanted: LogitechDevice) -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: logitechVendorID,
            kIOHIDProductIDKey: wanted.productID
        ] as CFDictionary)
        // Don't open the manager here — `IOHIDDeviceOpen` later does the work.
        guard let raw = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !raw.isEmpty else {
            return nil
        }
        // Prefer device whose location/serial matches if both available; else return first.
        if let serial = wanted.serialNumber {
            for d in raw {
                let s = IOHIDDeviceGetProperty(d, kIOHIDSerialNumberKey as CFString) as? String
                if s == serial { return d }
            }
        }
        return raw.first
    }
}
