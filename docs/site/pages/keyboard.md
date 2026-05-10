---
title: Keyboard
section: Features
order: 160
description: Backlight2 (0x1982) controls keyboard backlight modes and brightness. FnInversion (0x40A3) toggles Fn-lock.
lede: For MX Keys and friends, two HID++ features you actually care about — backlight modes and Fn-lock. Optune surfaces both, the rest stays out of your way.
---

# Keyboard

## Backlight2 (`0x1982`)

The Backlight2 feature controls per-key illumination on the MX Keys family. Three writes:

| Function | Effect |
|---|---|
| `GetBacklightConfig` | Returns supported modes, current mode, current intensity. |
| `SetBacklightConfig(mode, level)` | Sets mode and a 0–100 intensity. |
| `Subscribe` | Optune subscribes so the panel updates if you press the backlight ▲/▼ keys directly. |

Modes the firmware exposes (subset varies by model):

- **Off** — backlight always off, ignores intensity
- **On** — always on at the configured intensity
- **Reactive** — fades up briefly when you type, fades back down
- **Adaptive** — uses the keyboard's ambient light sensor (MX Keys S only)

Settings → **Keyboard** has a row per mode plus an intensity slider. The slider is hidden for **Off** and **Adaptive** because those modes don't honour it.

## FnInversion (`0x40A3`)

Fn-lock decides whether the F-keys default to **media** (volume, brightness) or **function** (F1–F12). Without Fn-lock, you have to hold the Fn key to flip the meaning. With it, the meaning is inverted permanently.

The HID++ feature gates this with two flags:

- **invertible** — false on cheap keyboards, true on MX Keys
- **inverted** — current state

If `invertible` is false, Optune greys out the toggle and explains why ("This keyboard's firmware does not expose Fn-lock"). Some Logi keyboards have a physical Fn-lock LED instead — the toggle on those is `Fn + Esc`, not anything Optune can drive.

## Multi-keyboard

If you have two Logi keyboards connected (e.g. an MX Keys S at the desk and an MX Keys Mini in the bag), Settings → Keyboard shows a picker at the top. Each keyboard remembers its own backlight mode + Fn-lock state.

## CLI

```bash
optune backlight                          # show mode + intensity
optune backlight --mode reactive --level 60
optune fnlock --enable
optune fnlock --disable
```
