---
title: Buttons & Action Catalog
section: Features
order: 130
description: Custom button remap with 40+ named actions across 8 categories — keystrokes, mouse, media, system. Powered by ReprogControlsV4 and a CGEventTap.
lede: 40+ named actions across 8 categories. No keycode hunting, no AppleScript, no Karabiner-Elements. Pick from a menu, the binding is live.
---

# Buttons

## What you can bind

Every remappable control on your device shows up in **Settings → Buttons**. Optune queries `ReprogControlsV4` (`0x1B04`) once per device, gets the native button list (Forward, Back, Wheel Click, Gesture, Top, Smart Shift, etc.), and shows them as rows.

Each row has a dropdown sourced from the **Action Catalog** — 40+ named actions, organised into 8 categories so you don't have to scroll a flat list of 40 things:

| Category | Examples |
|---|---|
| **Window** | Mission Control · App Exposé · Show Desktop · Launchpad |
| **Edit** | Cut · Copy · Paste · Undo · Redo · Find · Find Next |
| **Navigation** | Back · Forward · Home · End · Page Up · Page Down |
| **Media** | Play/Pause · Next · Previous · Volume Up/Down · Mute · Brightness Up/Down |
| **Mouse** | Left Click · Right Click · Middle Click · Cycle DPI · Toggle SmartShift · Toggle Scroll Mode |
| **Spaces** | Move Left · Move Right · Switch to Space 1–4 |
| **System** | Spotlight · Notification Center · Lock Screen · Force Quit · Screenshot Region |
| **App Launch** | Open Finder · Open Safari · Open Mail · Custom… |

The catalog is a Swift `enum RemapAction` with associated values and lives in `Sources/OptuneApp/ActionCatalog.swift`. Reverse lookup is O(1) so the dropdown finds your saved binding instantly.

## How a remap fires

When you press a remapped button:

1. The HID++ device sends a divert event for that button (because Optune set `divert=1` via `ReprogControlsV4.setRemap` at startup).
2. Optune's `RemapEngine` receives the divert in its HID++ listener.
3. It looks up the button in the active profile (per-app or global).
4. It dispatches the action through the right primitive:

| Action kind | Primitive |
|---|---|
| `keystroke(keyCode, modifiers)` | `CGEvent` keyboard down + up |
| `mouseClick(button)` | `CGEvent` mouse down + up at current cursor location |
| `mediaKey(nx)` | `NSEvent.otherEvent(...) → NSApp.postEvent(...)` (subtype 8 system-defined) |
| `cycleDPI` / `toggleSmartShift` / `toggleScrollMode` | Via `RemapActionDispatcher` singleton, which talks to `DeviceModel` |
| `runShell(path)` | `Process.launch()` (Custom… category) |
| `openApp(bundleID)` | `NSWorkspace.openApplication` |

The `RemapActionDispatcher` is a thin singleton that exists so the `RemapEngine` doesn't hold a strong reference to `DeviceModel` — that would leak on device disconnect.

## Per-app overrides

Each profile in **Settings → Per-App Profiles** has its own bindings dictionary. When you switch focus, the engine swaps the active dictionary in O(1) — there's no rebuild.

If a per-app profile **doesn't** override a button, the global binding is used. So you can have one global "Mission Control" on the thumb button and only override Cmd+/ in Final Cut.

## Capabilities & gating

Some buttons can't be remapped — they're hardware-locked or the firmware refuses divert. The Buttons pane greys those rows out with a tooltip explaining why. Capabilities come from `devices.json` (per-family) and from the live `ReprogControlsV4.getCapabilities` response (per-control).

> **Why a catalog instead of free-form keystroke entry?** Mouser and Karabiner-Elements teach this lesson hard: 95% of users want "Mission Control", not `keyCode 0x7E + ctrl`. The catalog wraps the keycode primitives behind names, and the **Custom…** entry is still there for the 5%.

## CLI

```bash
optune buttons                          # list controls + current bindings
optune buttons --bind back=mission_control
optune buttons --reset-all
```

The CLI uses the same action identifiers the catalog uses — you can find the full list with `optune buttons --catalog`.
