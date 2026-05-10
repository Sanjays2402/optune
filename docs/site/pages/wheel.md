---
title: Wheel & SmartShift
section: Features
order: 120
description: SmartShift (HID++ 0x2111) toggles between ratcheted and free-spin scroll. Optune lets you bind it to a button and tweak the auto-shift threshold.
lede: SmartShift is the magic that flips your scroll wheel from clicky to free-spin when you flick it hard. Optune exposes the threshold and lets you bind the toggle to any button.
---

# Wheel & SmartShift

## SmartShift (`0x2111`)

Logitech's MX wheels can run in two modes:

- **Ratcheted** — clicky, resistance, one notch per scroll event
- **Free-spin** — frictionless, multiple events per flick, the wheel keeps spinning after you let go

SmartShift detects how hard you flick the wheel and switches mode automatically. The HID++ feature exposes:

| Field | What it does |
|---|---|
| `enabled` | Master on/off. Off = always ratcheted. |
| `threshold` (1–255) | Higher = needs a harder flick to switch to free-spin. Default ~50. |

## Toggle from a button

The Action Catalog includes **Toggle Scroll Mode**. Bind it to any button and pressing it flips between ratcheted-locked and free-spin-locked, ignoring SmartShift. Press again and SmartShift takes over.

A second action, **Toggle SmartShift**, enables/disables SmartShift itself. Useful if you find the auto-switch annoying — bind it to the wheel-down click (`MiddleClick`) and you can turn the heuristic off without opening Settings.

## Threshold UI

Settings → **Wheel** has a slider for `threshold`. The slider is mapped non-linearly so the useful 30–80 range gets most of the travel. Hover the slider for a live preview — Optune writes the value, lets you flick the wheel, then restores the previous value when you release.

## Wheel ratchet mode (`0x2150`)

For devices that have a **HiResScroll / RatchetSwitch** feature in addition to SmartShift, Optune wires up the same UI but writes through `0x2150` instead. The two features are mutually exclusive on a single wheel — `DeviceRegistry` knows which one each model exposes.

## SmoothScroll (`0x2121`) — pending

SmoothScroll is the high-resolution scrolling protocol that lets the host get sub-line increments. macOS has its own pixel-level scroll handling, so SmoothScroll mostly matters for in-app fine adjustment in apps like Logic Pro. We've reverse-engineered the report layout (it's in `HIDPP+SmoothScroll.swift` as a stub) but the v0.7 release ships SmartShift only — full SmoothScroll lands in v0.8.

## CLI

```bash
optune smartshift               # show current state
optune smartshift --enable
optune smartshift --threshold 60
optune smartshift --disable
```
