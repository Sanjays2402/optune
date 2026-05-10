import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
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
    /// Synthesize a mouse button click. 0=left, 1=right, 2=middle, 3=back, 4=forward.
    /// Inspired by Mouser's `mouse_*_click` actions — useful when you want the
    /// gesture button to act as a third mouse button rather than a keystroke.
    case mouseClick(button: Int)
    /// Inject a system-level media key (NSSystemDefined). 0=play/pause,
    /// 1=next, 2=prev, 3=volumeUp, 4=volumeDown, 5=mute, 6=brightUp, 7=brightDown.
    /// `keystroke` would only work if the user happens to know the matching F-key —
    /// this hits the same code path the Apple keyboard uses.
    case mediaKey(key: Int)
    /// Cycle through the user's DPI presets stored in settings.
    case cycleDPI
    /// Toggle SmartShift (ratchet ↔ free-spin sensitivity).
    case toggleSmartShift
    /// Toggle the wheel between physical ratchet and free-spin.
    case toggleScrollMode

    public var displayName: String {
        switch self {
        case .none: return "Disabled"
        case .keystroke(let kc, let mods):
            // Use the catalog when available — falls back to raw hex for
            // user-defined custom shortcuts.
            if let label = ActionCatalog.shared.lookup(keyCode: kc, modifiers: mods)?.label {
                return label
            }
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
        case .mouseClick(let b):
            switch b {
            case 0: return "Left Click"
            case 1: return "Right Click"
            case 2: return "Middle Click"
            case 3: return "Back (Mouse 4)"
            case 4: return "Forward (Mouse 5)"
            default: return "Mouse \(b)"
            }
        case .mediaKey(let k):
            switch k {
            case 0: return "Play / Pause"
            case 1: return "Next Track"
            case 2: return "Previous Track"
            case 3: return "Volume Up"
            case 4: return "Volume Down"
            case 5: return "Mute"
            case 6: return "Brightness Up"
            case 7: return "Brightness Down"
            default: return "Media \(k)"
            }
        case .cycleDPI: return "Cycle DPI Presets"
        case .toggleSmartShift: return "Toggle SmartShift"
        case .toggleScrollMode: return "Switch Scroll Mode"
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
        // Gate every CGEvent action on Accessibility trust. Without it the
        // call is a silent no-op and the user is left wondering why nothing
        // happened. We don't block — we still attempt the post and the OS
        // will drop it — but we flip a published flag so the UI can surface
        // a banner. (`AXIsProcessTrusted()` is a fast XPC ping.)
        let needsAX: Bool = {
            switch action {
            case .keystroke, .systemSwipe, .mouseClick, .mediaKey: return true
            default: return false
            }
        }()
        if needsAX, !AXIsProcessTrusted() {
            // Bump the checker so any open settings/welcome surfaces refresh,
            // and pop the system prompt (only fires once per process lifetime).
            Task { @MainActor in
                AccessibilityChecker.shared.refresh()
                AccessibilityChecker.shared.requestPrompt()
            }
            return
        }

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

        case .mouseClick(let button):
            // Synthesize a click at the current cursor position. Mouser's
            // Windows path uses MOUSEEVENTF_*; on macOS we go through
            // CGEvent.mouseEvent + the matching button index.
            dispatchQueue.async {
                let pt = CGEvent(source: nil)?.location ?? .zero
                let mapping: (downType: CGEventType, upType: CGEventType, btn: CGMouseButton) = {
                    switch button {
                    case 0: return (.leftMouseDown, .leftMouseUp, .left)
                    case 1: return (.rightMouseDown, .rightMouseUp, .right)
                    case 2: return (.otherMouseDown, .otherMouseUp, .center)
                    case 3: return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 3) ?? .center)
                    case 4: return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 4) ?? .center)
                    default: return (.otherMouseDown, .otherMouseUp, .center)
                    }
                }()
                let src = CGEventSource(stateID: .combinedSessionState)
                let down = CGEvent(mouseEventSource: src, mouseType: mapping.downType, mouseCursorPosition: pt, mouseButton: mapping.btn)
                let up   = CGEvent(mouseEventSource: src, mouseType: mapping.upType,   mouseCursorPosition: pt, mouseButton: mapping.btn)
                down?.post(tap: .cgSessionEventTap)
                up?.post(tap: .cgSessionEventTap)
            }

        case .mediaKey(let key):
            // System-defined keys live on the NSSystemDefined event subtype 8.
            // The data1 field encodes (keyCode << 16) | (state << 8). We post a
            // press + release pair so apps that listen to either edge respond.
            //
            // NSEvent.otherEvent + NSApp posting must run on the MainActor in
            // strict-concurrency mode, so we hop there explicitly.
            let nx: Int32 = {
                switch key {
                case 0: return 16   // NX_KEYTYPE_PLAY
                case 1: return 19   // NX_KEYTYPE_NEXT
                case 2: return 20   // NX_KEYTYPE_PREVIOUS
                case 3: return 0    // NX_KEYTYPE_SOUND_UP
                case 4: return 1    // NX_KEYTYPE_SOUND_DOWN
                case 5: return 7    // NX_KEYTYPE_MUTE
                case 6: return 2    // NX_KEYTYPE_BRIGHTNESS_UP
                case 7: return 3    // NX_KEYTYPE_BRIGHTNESS_DOWN
                default: return 16
                }
            }()
            Task { @MainActor in
                Self.postMediaKey(nx: nx)
            }

        case .cycleDPI:
            // Hop into MainActor land — the model lives there.
            Task { @MainActor in
                RemapActionDispatcher.shared?.cycleDPI()
            }

        case .toggleSmartShift:
            Task { @MainActor in
                RemapActionDispatcher.shared?.toggleSmartShift()
            }

        case .toggleScrollMode:
            Task { @MainActor in
                RemapActionDispatcher.shared?.toggleScrollMode()
            }
        }
    }

    /// Post an NSSystemDefined media key press + release. Splits the work into
    /// a free function so the dispatchQueue.async block above stays readable.
    private static func postMediaKey(nx: Int32) {
        for state in [0xa, 0xb] { // 0xa = key down, 0xb = key up
            let data1 = (Int(nx) << 16) | (state << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
