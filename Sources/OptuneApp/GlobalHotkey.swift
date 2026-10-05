import Carbon.HIToolbox
import Foundation

/// Single system-wide hotkey via Carbon `RegisterEventHotKey` — works without
/// Accessibility or Input Monitoring permission.
@MainActor
final class GlobalHotkey {
    static let shared = GlobalHotkey()

    nonisolated(unsafe) fileprivate static var action: (@Sendable () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    /// Register ⌃⌥ + key (replacing any existing registration).
    func register(keyCode: UInt32, action: @escaping @Sendable () -> Void) {
        unregister()
        Self.action = action
        if !handlerInstalled {
            var spec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { GlobalHotkey.action?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x4F505455), id: 1)   // 'OPTU'
        RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
        Self.action = nil
    }
}
