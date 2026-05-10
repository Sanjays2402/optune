# Adding a Device

Optune's device registry lives in
[`Sources/OptuneCore/Resources/devices.json`](../Sources/OptuneCore/Resources/devices.json).
Adding a device is a **one-file PR** — no Swift changes required.

## Steps

1. Find the device's USB Product ID (PID) for every transport it ships on
   (Bolt receiver, Unifying receiver, direct USB, direct Bluetooth). Solaar's
   [`descriptors.py`](https://github.com/pwr-Solaar/Solaar/blob/master/lib/logitech_receiver/descriptors.py)
   is the canonical reference. PIDs are 16-bit hex (e.g. `0xB034`).

2. Append a new entry to the `devices` array in `devices.json`:

   ```json
   {
     "modelName": "MX Master 5",
     "codename": "mx-master-5",
     "pids": ["0xB050", "0x4090"],
     "supportsBattery": true,
     "supportsDPI": true,
     "supportsSmartShift": true,
     "supportsThumbWheel": true,
     "supportsButtonRemap": true,
     "supportsGestures": true,
     "supportsSmoothScroll": true,
     "supportsEasySwitch": true,
     "dpiMin": 200,
     "dpiMax": 8000,
     "defaultSmartShiftThreshold": 25
   }
   ```

3. Set capability flags to `false` **only** when you know the hardware lacks
   the feature (e.g. MX Vertical has no thumb wheel → `supportsThumbWheel: false`).
   HID++ feature probing is the runtime source of truth — flags here are
   pre-flight UI hints.

4. Run `swift test` — `DeviceRegistryTests` will fail loudly if the JSON
   doesn't decode or your PIDs collide with an existing entry.

5. Open the PR with `[device]` in the title. Bonus points for attaching the
   `optune doctor` output from the new device.

## Field reference

| Field                          | Type     | Required | Notes |
| ------------------------------ | -------- | :------: | ----- |
| `modelName`                    | String   | ✅       | Marketing name. |
| `codename`                     | String   | ✅       | kebab-case slug. Used in CLI matchers. |
| `pids`                         | `[String]` | ✅     | Hex strings (`"0xB034"`). One entry per transport. |
| `supportsBattery`              | Bool     | ✅       | Feature `0x1004` UnifiedBattery. |
| `supportsDPI`                  | Bool     | ✅       | Feature `0x2201` AdjustableDPI. |
| `supportsSmartShift`           | Bool     | ✅       | Feature `0x2111` SmartShift. |
| `supportsThumbWheel`           | Bool     | ✅       | Feature `0x2150` ThumbWheel. |
| `supportsButtonRemap`          | Bool     | ✅       | Feature `0x1B04` ReprogControlsV4. |
| `supportsGestures`             | Bool     | ✅       | Software-side via gesture button divert. |
| `supportsSmoothScroll`         | Bool     | ✅       | Feature `0x2121` HiResWheel. |
| `supportsEasySwitch`           | Bool     | ✅       | Feature `0x1814`/`0x1815` host switching. |
| `dpiMin` / `dpiMax`            | Int      | ✅       | DPI clamp bounds. Datasheet values. |
| `defaultSmartShiftThreshold`   | UInt8    | ✅       | 1…50, datasheet/observed default. |

## When to edit Swift instead of JSON

You only need to touch Swift when:

- You're adding a **new HID++ feature** (new file under `Sources/OptuneCore/Features/`).
- You're adding a **new capability flag** that doesn't exist in `DeviceDescriptor` yet.
- You're adding **transport-level quirks** (e.g. devices that need short-report
  fallback, or a unique `IOReturn` rejection signature).

Everything else — new PID variants, new model names, new DPI ranges — is a
JSON-only change.
