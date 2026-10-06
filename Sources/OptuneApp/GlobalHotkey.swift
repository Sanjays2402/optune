import Carbon.HIToolbox
import Foundation

/// System-wide hotkeys via Carbon `RegisterEventHotKey` — works without
/// Accessibility or Input Monitoring permission. All hotkeys use ⌃⌥ + a key.
@MainActor
final class GlobalHotkey {
    static let shared = GlobalHotkey()

    nonisolated(unsafe) fileprivate static var actions: [UInt32: @Sendable () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    /// Register ⌃⌥ + `keyCode` under `id` (replacing any existing registration for that id).
    func register(id: UInt32, keyCode: UInt32, action: @escaping @Sendable () -> Void) {
        unregister(id: id)
        Self.actions[id] = action
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F505455), id: id)   // 'OPTU'
        let status = RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs[id] = ref } else { Self.actions[id] = nil }
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        Self.actions[id] = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr {
                let id = hotKeyID.id
                DispatchQueue.main.async { GlobalHotkey.actions[id]?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
