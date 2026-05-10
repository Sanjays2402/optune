// RemapActionDispatcher.swift
// Bridge that lets the lower-level `RemapEngine` (which owns no app state)
// invoke high-level `DeviceModel` writes — DPI cycle, SmartShift toggle,
// scroll-mode toggle — when a remap fires `cycleDPI` / `toggleSmartShift` /
// `toggleScrollMode`.
//
// We could have given `RemapEngine` a `weak var model: DeviceModel?` and
// called methods directly, but that creates a retain cycle (`DeviceModel`
// owns the engine through the device's transport snapshot) and forces
// every test to mock a full DeviceModel. A singleton dispatcher with weak
// references is the cleanest split: engines stay testable, the model
// registers itself on init and unregisters on deinit.
//
// All callbacks land on the MainActor because `DeviceModel` is `@MainActor`.

import Foundation

@MainActor
public final class RemapActionDispatcher {
    /// Singleton handle. `nil` until `DeviceModel` registers itself.
    public static var shared: RemapActionDispatcher?

    public weak var model: AnyObject?

    /// Closures the model registers when it boots. Held strongly here, weak
    /// reference to model is via `[weak target]` capture inside the model
    /// itself when it builds these — see `DeviceModel.installRemapDispatcher()`.
    public var onCycleDPI: () -> Void = {}
    public var onToggleSmartShift: () -> Void = {}
    public var onToggleScrollMode: () -> Void = {}

    public init() {}

    public func cycleDPI() { onCycleDPI() }
    public func toggleSmartShift() { onToggleSmartShift() }
    public func toggleScrollMode() { onToggleScrollMode() }
}
