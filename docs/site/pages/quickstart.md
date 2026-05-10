---
title: Quickstart
section: Start
order: 30
description: Two minutes from install to your first custom button remap.
lede: Two minutes from install to your first remap. We'll plug in a mouse, set a DPI preset, and bind the thumb button to "Mission Control".
---

# Quickstart

## 1. Pair the device

If your mouse came with a Logi Bolt receiver, plug it in. Otherwise pair over Bluetooth via System Settings → Bluetooth. **Optune does not ship its own pairing UI** — macOS handles that, and Optune picks up whatever is paired.

## 2. Open Optune

```bash
open -a Optune
```

A dot appears in the menu bar. Click it. You should see your device with a battery percentage, a DPI pill, and a SmartShift pill.

> If the device is missing, run `optune doctor` from the terminal. It dumps every HID interface IOKit knows about and tells you whether HID++ responded.

## 3. Set a DPI preset

In the menu-bar dropdown, click your device → **Pointer**. Drag the slider, or pick from the dropdown. Optune writes via `setSensitivity()` on `AdjustableDPI` (`0x2201`) so the change is instant and persists across sleep cycles.

Three named presets ship by default — **Low / Med / High** — anchored to your device's sensor range from `devices.json`. You can edit the preset values in **Settings → Pointer**.

## 4. Remap the thumb button

Open **Settings** (Cmd+,) → **Buttons**. Optune queries `ReprogControlsV4` (`0x1B04`) once and lists every remappable control with its native label and a dropdown.

Find the **Back** button (the lower thumb button on an MX Master). Click the dropdown. The new **Action Catalog** shows 40+ named actions grouped by category:

- **Window** — Mission Control, App Exposé, Show Desktop, Launchpad
- **Edit** — Cut, Copy, Paste, Undo, Redo
- **Navigation** — Forward, Back, Page Up/Down, Home, End
- **Media** — Play/Pause, Next, Previous, Volume, Brightness
- **Mouse** — Left/Right/Middle Click, Cycle DPI, Toggle SmartShift, Toggle Scroll Mode
- **System** — Spotlight, Notification Center, Lock Screen, Force Quit

Pick **Mission Control**. The change is live — press the thumb button and Mission Control pops up. Optune used a `CGEventTap` to intercept the original button press and a `CGEvent` (or `NSEvent.otherEvent` for media keys) to fire the new one.

## 5. Make it stick to apps

Settings → **Per-App Profiles** → click **+**. Pick an app (e.g. Final Cut Pro). The profile inherits your global remap; tweak whatever you want, save, and the next time Final Cut comes to the front Optune flips DPI, SmartShift, scroll mode, and bindings to match.

The flip happens via an `NSWorkspace` activation observer, so there's no polling — it's instant when you Cmd-Tab.

## You're done

Five things in two minutes. The rest of the docs go deep on each surface. Pick the one you care about from the sidebar.
