---
title: Pointer & DPI
section: Features
order: 110
description: How AdjustableDPI (HID++ 0x2201) works, how Optune named presets bind to the firmware sensor range.
lede: Optune uses AdjustableDPI (0x2201) to read your sensor's range and write a new value instantly. Presets are stored per-device and per-app.
---

# Pointer & DPI

## The feature: AdjustableDPI (`0x2201`)

`AdjustableDPI` is the HID++ feature that exposes the sensor's resolution range and lets you set a new value without rebooting the device. It's universal across MX Master generations, MX Anywhere, and MX Vertical.

Three function calls:

| Function | What it returns |
|---|---|
| `GetSensorCount` | Number of independent sensors (always 1 on consumer devices). |
| `GetSensorDpiList` | Min/max DPI in steps the firmware accepts. |
| `GetSensorDpi` / `SetSensorDpi` | Current value and the setter. |

## How presets work

Optune ships three named presets per device: **Low / Med / High**. The values are computed from the firmware-reported range:

- **Low** = `range.min`
- **High** = `range.max`
- **Med** = midpoint, rounded to the nearest legal step

So an MX Master 3S with a `[200, 8000]` range gets presets at **200 / 4000 / 8000**. An MX Anywhere 3 with `[200, 4000]` gets **200 / 2000 / 4000**.

You can edit the values per device in **Settings → Pointer**. They're stored in `~/Library/Preferences/com.sanjays2402.optune.plist` keyed by the device's `productID`.

## Cycle DPI from a button

In the Buttons pane, the **Cycle DPI** action rotates through your presets. Each press goes Low → Med → High → Low. The action fires through the [Action Catalog](buttons.html), no special wiring needed.

When you cycle, Optune emits a brief **HUD overlay** with the new value so you don't have to look at the menu bar to confirm.

## Per-app DPI

Per-app profiles store a DPI value distinct from the global one. When the focused app changes, Optune's `NSWorkspace.didActivateApplicationNotification` observer:

1. Looks up the bundle ID in the profile store
2. If found, applies the profile's DPI via `setSensorDpi`
3. If not, applies the global default

The flip is debounced 50 ms so rapidly Cmd-Tabbing doesn't thrash the firmware.

## CLI

```bash
optune dpi
optune dpi --set 1600
optune dpi --device "MX Master 3S" --set 4000
```

`optune dpi` with no arguments prints the current value and the firmware-reported range.

## Sensor caveats

- **Onboard mode** locks DPI to one of the three onboard slots. If the device is in onboard mode, `setSensorDpi` is rejected with `INVALID_ARGUMENT`. Optune detects this and shows a banner saying "switch to host mode to use DPI presets" — see [Onboard](onboard.html).
- The **MX Vertical** has a quirk where setting DPI under 400 disables tracking entirely until reset. Optune clamps the slider min to 400 for that device family.
