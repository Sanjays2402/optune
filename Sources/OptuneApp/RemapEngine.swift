import Foundation
import CoreGraphics
import AppKit
import OptuneCore

/// What action to fire when a diverted CID is pressed.
public enum RemapAction: Codable, Equatable, Sendable, Hashable {
    /// No-op — explicitly silence the button.
    case none
    /// Synthesize a key-down + key-up event at the global event tap level.
    /// Modifiers is a CGEventFlags raw value (Cmd, Shift, etc.).
    case keystroke(keyCode: Int, modifiers: UInt64)
    /// Mission Control / Spaces / App Expose via the existing 4-way swipe shape.
    /// 0=missionControl, 1=appExpose, 2=showDesktop, 3=launchpad.
    case systemSwipe(slot: Int)
    /// Open an app by bundle identifier.
    case openApp(bundleID: String)
    /// Run a shell command (string is passed to /bin/zsh -lc).
    case runShell(String)

    public var displayName: String {
        switch self {
        case .none: return "Disabled"
        case .keystroke(let kc, let mods):
            let modName = modifierName(mods)
            return modName.isEmpty ? "Key 0x\(String(kc, radix: 16))" : "\(modName) + 0x\(String(kc, radix: 16))"
        case .systemSwipe(let s):
            switch s {
            case 0: return "Mission Control"
            case 1: return "Application Windows"
            case 2: return "Show Desktop"
            case 3: return "Launchpad"
            default: return "Swipe \(s)"
            }
        case .openApp(let id): return "Open \(id)"
        case .runShell(let cmd): return "Shell: \(cmd.prefix(32))…"
        }
    }

    private func modifierName(_ raw: UInt64) -> String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: raw)
        if flags.contains(.maskCommand) { parts.append("⌘") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        return parts.joined()
    }
}

/// Per-CID remap entry. Stored as a dictionary keyed by CID under each device.
public struct RemapBinding: Codable, Equatable, Sendable {
    public var cid: UInt16
    public var action: RemapAction
    public init(cid: UInt16, action: RemapAction) {
        self.cid = cid
        self.action = action
    }
}

/// Runtime engine that subscribes to HID++ button events on a transport,
/// debounces edge-trigger semantics (only fires on rising edge), and
/// dispatches the bound `RemapAction`.
///
/// The engine doesn't open the transport itself — it expects to be handed
/// a live `HIDPPTransport` (the `DeviceModel` already maintains those for
/// telemetry polling, so we piggy-back). When the device disconnects, the
/// engine is torn down and the firmware reverts diversion automatically.
@MainActor
final class RemapEngine {
    private let transport: HIDPPTransport
    private var subToken: UInt64?
    private var lastPressed: Set<UInt16> = []
    private var bindings: [UInt16: RemapAction] = [:]
    private let dispatchQueue = DispatchQueue(label: "io.github.sanjays2402.optune.remap", qos: .userInitiated)

    /// Initialize against a live transport and apply the initial bindings.
    init(transport: HIDPPTransport) {
        self.transport = transport
    }

    /// Replace the binding map and reconcile firmware divert flags. CIDs that
    /// have any non-`.none` binding get diverted; otherwise they're cleared.
    func apply(bindings: [RemapBinding], featureIndex: UInt8) async {
        var map: [UInt16: RemapAction] = [:]
        for b in bindings { map[b.cid] = b.action }
        self.bindings = map

        // Reconcile: get every control, divert the bound ones, un-divert the rest.
        do {
            let controls = (try? await ReprogControlsV4Feature.snapshot(on: transport)) ?? []
            for control in controls where control.isReprogrammable {
                let action = map[control.cid]
                let wantDiverted = action != nil && action != .some(.none)
                _ = try? await ReprogControlsV4Feature.setReporting(
                    on: transport,
                    featureIndex: featureIndex,
                    reporting: .init(cid: control.cid, diverted: wantDiverted)
                )
            }
        }

        // Make sure we're listening for button events.
        if subToken == nil {
            subToken = transport.addEventSubscriber { [weak self] response in
                guard let self else { return }
                guard let event = ReprogControlsV4Feature.decodeButtonEvent(response) else { return }
                Task { @MainActor in self.handle(event: event) }
            }
        }
    }

    /// Tear down: unsubscribe and clear all diversions on the device.
    func teardown(featureIndex: UInt8) async {
        if let t = subToken {
            transport.removeEventSubscriber(t)
            subToken = nil
        }
        let controls = (try? await ReprogControlsV4Feature.snapshot(on: transport)) ?? []
        for control in controls where control.isReprogrammable {
            _ = try? await ReprogControlsV4Feature.setReporting(
                on: transport,
                featureIndex: featureIndex,
                reporting: .init(cid: control.cid, diverted: false)
            )
        }
        bindings.removeAll()
        lastPressed.removeAll()
    }

    private func handle(event: ReprogControlsV4Feature.ButtonEvent) {
        // Rising edge: CIDs in `pressedCIDs` that weren't there before.
        let rising = event.pressedCIDs.subtracting(lastPressed)
        lastPressed = event.pressedCIDs
        for cid in rising {
            guard let action = bindings[cid], action != .none else { continue }
            fire(action: action)
        }
    }

    private func fire(action: RemapAction) {
        switch action {
        case .none:
            return

        case .keystroke(let keyCode, let modifiers):
            dispatchQueue.async {
                let src = CGEventSource(stateID: .combinedSessionState)
                let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: true)
                let up   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: false)
                down?.flags = CGEventFlags(rawValue: modifiers)
                up?.flags   = CGEventFlags(rawValue: modifiers)
                down?.post(tap: .cgSessionEventTap)
                up?.post(tap: .cgSessionEventTap)
            }

        case .systemSwipe(let slot):
            // macOS exposes Mission Control etc. via stable F-key codes.
            // F3 = Mission Control, ⌃↓ = Application Windows, F11 = Show Desktop, F4 = Launchpad.
            let pair: (Int, UInt64)
            switch slot {
            case 0:  pair = (160, 0)                                            // F3 (Mission Control)
            case 1:  pair = (125, CGEventFlags.maskControl.rawValue)            // ⌃↓ (App Expose)
            case 2:  pair = (103, 0)                                            // F11 (Show Desktop)
            case 3:  pair = (131, 0)                                            // F4 (Launchpad)
            default: pair = (160, 0)
            }
            fire(action: .keystroke(keyCode: pair.0, modifiers: pair.1))

        case .openApp(let bundleID):
            DispatchQueue.main.async {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }

        case .runShell(let cmd):
            dispatchQueue.async {
                let p = Process()
                p.launchPath = "/bin/zsh"
                p.arguments = ["-lc", cmd]
                try? p.run()
            }
        }
    }
}
