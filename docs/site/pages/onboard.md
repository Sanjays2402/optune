---
title: Onboard & Profiles
section: Features
order: 150
description: OnboardProfiles (0x8100) controls host vs onboard mode and the active onboard slot. Persist DPI/buttons across machines without an app.
lede: Onboard mode lets your mouse keep its DPI, button bindings, and SmartShift settings without any host software running. Optune lets you switch between host and onboard mode and pick the active slot.
---

# Onboard & Profiles

## OnboardProfiles (`0x8100`)

The mouse has two operating modes:

- **Host mode** — DPI, button bindings, SmartShift come from whatever software is running on the connected host (Optune, Options+, or nothing).
- **Onboard mode** — the mouse uses settings stored in its own flash. Three slots (or five on some devices), each with DPI, buttons, SmartShift, polling rate.

Onboard mode is what makes a mouse useful when you plug it into a machine that doesn't have your software. Optune's job here is to:

1. Tell you which mode you're in
2. Let you switch
3. Show which onboard slot is active

## Mode switch

Settings → **Onboard** has a segmented control: **Host / Onboard**. Switching writes via `setMode(mode)`. The change is immediate.

When the device is in **onboard mode**:

- DPI presets (the [Pointer pane](pointer.html)) stop working — `setSensorDpi` returns `INVALID_ARGUMENT`. Optune detects this and shows a banner.
- Button remaps **also** stop working — the device honours its onboard bindings instead. Optune shows the same banner in Buttons.
- SmartShift and Hosts still work normally — those features ignore the host/onboard split.

## Slot picker

In onboard mode, Optune shows three slot buttons. Picking one writes `setActiveProfile(slot)` and the device flashes its slot LED to confirm.

The slot **contents** (which DPI presets, which button bindings each slot holds) are read-only in v0.6. Writing onboard slot content needs the `ReprogControlsV4` onboard write report types, which we've reverse-engineered but haven't shipped yet — that lands in v0.8.

## Why this matters

The single most useful real-world workflow:

1. Pair the mouse with your work Mac (host slot 1) and your home Mac (host slot 2)
2. Configure DPI presets and button remaps on each Mac with Optune
3. Onboard slot 1 mirrors the work Mac's settings; slot 2 mirrors home
4. When you walk to a Mac that doesn't have Optune installed (a meeting room, a friend's machine), switch to **onboard mode + slot 1** and your mouse behaves the same as on your work Mac

That's the closed-source Logi Options+ flow, replicated in 80 lines of Swift.

## CLI

```bash
optune onboard                       # show current mode + slot
optune onboard --mode onboard        # switch to onboard
optune onboard --mode host
optune onboard --slot 2              # pick onboard slot 2
```
