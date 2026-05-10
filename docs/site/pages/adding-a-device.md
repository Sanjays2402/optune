---
title: Adding a device
section: Reference
order: 220
description: Add a new Logitech device to Optune in one PR — no Swift changes, just a JSON entry.
lede: Got a Logitech device that isn't in the registry? Add it in one PR — pure JSON, no Swift, runs in CI.
---

# Adding a device

## Why a registry

Optune's `DeviceRegistry` is a JSON file at `Sources/OptuneCore/Resources/devices.json`. It maps a Logitech wireless PID (or USB VID:PID pair) to:

- Friendly name + family
- Sensor DPI range (firmware ground truth)
- Capability flags — does this device have SmartShift? Backlight? Onboard slots?

The registry exists because firmware reports can lie or be missing. A device that exposes `AdjustableDPI` might have a sensible `[200, 8000]` range over USB but report `[0, 0]` over BLE on first connection. The registry gives us a fallback so the UI doesn't show 0 DPI for half a second on every wake.

It also lets us **gate UI per family** — MX Anywhere has no SmartShift, so the Wheel pane hides SmartShift for that family.

## The JSON shape

Open `Sources/OptuneCore/Resources/devices.json` and you'll see entries like:

```json
{
  "wirelessPID": "B034",
  "name": "MX Master 3S",
  "family": "mx_master",
  "dpiRange": { "min": 200, "max": 8000, "step": 50 },
  "capabilities": {
    "smartShift": true,
    "onboardProfiles": true,
    "buttonRemap": true,
    "hosts": 3,
    "backlight": false,
    "fnLock": false
  }
}
```

## Steps to add yours

1. **Find the wireless PID.** Run `optune doctor`. Look for a row like `productID=0xB034 transport=BLE`. The four hex digits without `0x` are the wireless PID.
2. **Look up the sensor range.** Logitech publishes the DPI range on the product page. Or, if you trust your firmware, run `optune dpi` and copy the range from `--json` output.
3. **Determine capabilities.** Run `optune doctor --features` to see which HID++ features the firmware advertises. Cross-reference:

   | Feature ID | Capability flag |
   |---|---|
   | `0x2111` | `smartShift` |
   | `0x8100` | `onboardProfiles` |
   | `0x1B04` | `buttonRemap` |
   | `0x1815` | `hosts` (set to `getHostCount` result) |
   | `0x1982` | `backlight` |
   | `0x40A3` | `fnLock` |

4. **Add the entry** to `devices.json` in alphabetical order by `wirelessPID`.
5. **Add a test fixture** at `Tests/OptuneCoreTests/Fixtures/<pid>.bin` with a captured HID++ feature-set dump. (Optional but encouraged — it locks the registry against firmware changes.)
6. **Run the tests.**

   ```bash
   swift test --filter DeviceRegistryTests
   ```

   The `DeviceRegistryTests` suite parses the JSON, checks every entry has a unique PID, validates the DPI range monotonicity, and confirms each capability flag corresponds to a known feature ID.

7. **Open a PR.** No Swift changes, no Xcode project edits — just a JSON delta and (ideally) a fixture. CI runs the suite on macos-15 with full Xcode and signs off.

## Gotchas

- **USB and BLE pairings have different PIDs.** Add both. The MX Master 3S is `B034` over BLE and `406A` over a Bolt receiver.
- **Don't make up a `family`.** If yours doesn't fit the existing list (`mx_master`, `mx_anywhere`, `mx_vertical`, `mx_keys`, `mx_keys_mini`), pick the closest one. The family controls some UI gating; orphan families silently lose features.
- **`step` matters.** A device with a 50-DPI step rejects `setSensorDpi(1601)` with `INVALID_ARGUMENT`. The slider snaps to the step.

## Live testing without a release

Once the PR merges, the device works in `swift run optune` immediately. To verify the menu-bar app picks it up:

```bash
swift build -c release
bash Scripts/bundle-app.sh release
open .build/OptuneApp.app
```
