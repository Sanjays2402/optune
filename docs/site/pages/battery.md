---
title: Battery
section: Features
order: 100
description: How Optune reads UnifiedBattery (HID++ 0x1004) and what the percent, status, and charge fields mean.
lede: One feature, four meaningful bits — percent, status, charge state, and external power. Optune polls UnifiedBattery (0x1004) on a 30-second cadence and keeps a rolling sparkline.
---

# Battery

## The feature: UnifiedBattery (`0x1004`)

Modern Logitech mice and keyboards expose battery level via the **UnifiedBattery** feature. It supersedes the legacy `BatteryStatus` (`0x1000`) and `BatteryVoltage` (`0x1001`) features and reports a clean percentage instead of a coarse "low / good / full" enum.

The feature has two main reads:

- **GetCapabilities** (`fn 0x00`) — tells you which optional fields the firmware supports.
- **GetStatus** (`fn 0x10`) — returns the live snapshot.

## Status report layout

The 16-byte response from `GetStatus` parses as:

```
byte 0   percent          0..100, or 0xFF if unknown
byte 1   level mask       enum (critical, low, good, full)
byte 2   status           0=discharging 1=charging 2=charge_done 4=charge_slow 8=invalid
byte 3   external power   0=no 1=yes
bytes 4-15  reserved
```

Optune surfaces three of these:

| UI element | Source field | Notes |
|---|---|---|
| Battery pill | `percent` | Shows "?" if firmware returns 0xFF. |
| Charge bolt | `status == charging` | Animated when charging, solid when full, hidden otherwise. |
| External plug glyph | `external power == 1` | Only shown when `status != charging` (charging implies external power). |

## Why the percent disagrees with Logi Options+

UnifiedBattery's percent is calibrated by Logi from a discharge curve baked into firmware — it's the same number Options+ shows. If they disagree, check:

1. You're looking at the **same device**. MX Master 3S over BLE and over the Bolt receiver appear as two distinct HID interfaces on macOS.
2. Optune polls every 30 seconds. Plugging in shifts the curve immediately; the pill catches up on the next tick.

## Sparkline history

The menu-bar dropdown shows a 60-sample rolling sparkline. Each sample is the percent at the time of the poll, persisted to `~/Library/Application Support/Optune/battery-history.json`.

Three things to know:

- The sparkline is **per-device** (keyed by serial / wireless PID).
- It does not reset on app launch.
- Samples while charging are stored with a flag, so the line dips and rises distinctly.

## Notifications

Optune posts a UNUserNotification once per discharge cycle when:

- `percent` crosses the **low threshold** (default 20%, configurable in Settings → Notifications)
- `percent` crosses the **critical threshold** (default 5%)
- The device disconnects while below 20%

The threshold + a "Notify on charge complete" toggle live in Settings.

## CLI

```bash
optune battery
optune battery --json
optune battery --device "MX Master 3S"
```

`--json` is the format the menu-bar app uses internally; it's stable, you can parse it from a script.

## Quirks

- The **MX Anywhere 2S** firmware sometimes reports 0% for a few seconds after wake. Optune debounces — anything that comes within 5 seconds of waking is dropped from the sparkline.
- The **MX Keys S** keyboard rarely returns `external_power=1` while charging; we trust `status==charging` over the `external_power` bit when both are set.
