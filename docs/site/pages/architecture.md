---
title: Architecture
section: Reference
order: 210
description: How OptuneCore, OptuneApp, and the CLI fit together. A guided tour of the HID++ stack and the SwiftUI surface.
lede: A guided tour of the layers — IOKit at the bottom, SwiftUI at the top, OptuneCore in the middle keeping both honest.
---

# Architecture

## Layers

```
┌─────────────────────────────────────────┐
│  SwiftUI (menu bar + Settings + welcome)│  OptuneApp
│  RemapEngine, ProfileStore, Notifications│
├─────────────────────────────────────────┤
│  DeviceModel, DeviceRegistry             │  OptuneCore
│  HIDPP feature set (battery, dpi, ...)   │  (Swift Package)
│  HIDPPTransport                          │
├─────────────────────────────────────────┤
│  IOHIDManager + IOHIDDevice              │  IOKit
└─────────────────────────────────────────┘
```

Two products, one package:

- **`OptuneCore`** — pure Swift package. No UIKit, no SwiftUI, no AppKit. Imports IOKit and Foundation only. Used by both the app and the CLI.
- **`OptuneApp`** — the SwiftUI app target. Owns Settings, the menu bar, profiles, notifications, the remap engine.

The CLI is a separate executable target inside the same Swift package. It depends on OptuneCore and prints — no GUI imports, so it builds on a headless macOS runner.

## Device discovery

`HIDPPTransport` opens an `IOHIDManager` with a matching dictionary that picks up Logitech vendor IDs (`0x046D`) and the HID++ usage page. When IOKit fires the `Matching` callback:

1. We call `IOHIDDeviceOpen` with `kIOHIDOptionsTypeSeizeDevice = 0` (we share, we don't seize)
2. We register an input report callback for **report 0x11** (HID++ long, 20 bytes)
3. We send a `getProtocolVersion` request — if the device responds, it's HID++ 2.0
4. We send `getFeatureSet.getCount` to enumerate features, then `getFeatureID(i)` for each feature index

The result is a `Device` value with a `featureMap: [FeatureID: FeatureIndex]`. Every subsequent feature call uses the cached index.

## HID++ frame layout

A HID++ "long" report (`0x11`) is exactly 20 bytes:

```
[ report=0x11 | dev=0xFF | featIdx | funcIdx<<4 | swid | param0..param15 ]
```

- `dev` is `0xFF` for the receiver itself, otherwise the slot of the connected device on the receiver.
- `featIdx` is the feature index from the cached feature map.
- `funcIdx` is the function index inside that feature, shifted left 4 bits.
- `swid` (software ID) is a 4-bit cookie we set per request to match responses to requests.
- `param0..15` is the function-specific payload.

`HIDPPTransport.send(...)` handles the cookie, async/await pairing, and timeouts. Features built on top — `UnifiedBattery`, `AdjustableDPI`, etc. — are typed wrappers that encode the params and decode the response.

## DeviceModel and ProfileStore

`DeviceModel` is the per-device `@MainActor` ObservableObject the SwiftUI views observe. It owns:

- The current battery snapshot
- The current DPI value + range
- The current SmartShift state
- A reference to the active `Profile` (global or per-app)

`ProfileStore` holds the profile dictionary keyed by bundle ID and persists to disk. The `NSWorkspace` activation observer lives in `OptuneApp.swift` and calls `DeviceModel.apply(profile)` directly.

## RemapEngine

`RemapEngine` is the trickiest bit. When you bind a button to an action:

1. The engine asks `ReprogControlsV4.setRemap(button, divert: true)`. This tells the firmware "stop firing the original event, send a divert HID++ packet instead".
2. The engine subscribes to divert packets via the HID++ transport's notification callback.
3. When a divert arrives, the engine looks up the current binding (per-app first, global fallback) and calls `fire(action:)`.
4. `fire(action:)` posts the synthesized event using whichever primitive matches — `CGEvent` for keystrokes / mouse clicks, `NSEvent.otherEvent + NSApp.postEvent` for media keys.

The engine **never holds** a strong reference to `DeviceModel`. Cycle DPI, Toggle SmartShift, Toggle Scroll Mode all go through `RemapActionDispatcher.shared`, a tiny singleton bridge that `DeviceModel` registers closures into at init time.

## Single-instance guard

Optune is a menu-bar app — running two copies makes no sense. `SingleInstanceGuard.acquireOrTrigger()` runs in `App.init()`:

1. If we're the **first** copy, register a `DistributedNotificationCenter` observer for `optune.activate` and proceed normally.
2. If we're the **second** copy, post `optune.activate` and call `exit(0)`.

The first copy's observer brings up Settings via `NSApp.sendAction(showSettingsWindow:, ...)`, so launching from the dock or `open -a Optune` while one is running just focuses the existing instance.

## Error handling philosophy

Every HID++ call returns `Result<Response, HIDPPError>`. Errors fall into:

- **Transport** — IOKit returned a kernel error, the device disappeared, the report didn't arrive in 1000 ms.
- **Protocol** — the device returned a HID++ error code (`INVALID_FUNCTION_ID`, `INVALID_ARGUMENT`, `OUT_OF_RANGE`).
- **Capability** — we asked for a feature the device doesn't have.

The UI never crashes on an HID++ error. Worst case a pane shows an empty state with a tooltip explaining the firmware response. The CLI exits with a non-zero code and prints the error to stderr.
