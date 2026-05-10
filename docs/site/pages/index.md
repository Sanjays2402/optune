---
title: Overview
section: Start
order: 10
nav_order: 10
description: Optune is a native, open-source Logitech Options+ replacement for macOS — built in Swift 6 with Liquid Glass UI.
lede: A native, open-source Logitech Options+ replacement for macOS. Optune talks to your mouse and keyboard over HID++ directly, without a daemon, an account, or a single line of telemetry.
---

# Overview

## What it is

Optune is a single ~3.8 MB universal app that pairs with your Logitech mice and keyboards over the **HID++ 2.0** protocol and exposes the bits Logi Options+ hides behind login walls and background services:

- Live battery (with charge state and external-power detection)
- Adjustable DPI with named presets
- SmartShift toggle and sensitivity
- Per-button remapping using a 40-action catalog
- Multi-host switching for devices that support it
- Keyboard backlight, Fn-lock, and onboard slot mode
- Per-app profiles that flip pointer + scroll behaviour when you switch focus

The whole surface is driven by **IOKit HIDManager** — no kernel extensions, no daemons, no login items, no helper services. Quit the app, every override stops.

## What it isn't

- **Closed source.** Optune ships the full Swift source under GPL-3.0.
- **Logged in.** There is no account, no cloud, no "Logi AI", no telemetry.
- **Cross-platform.** Optune is mac-only on purpose. Linux already has [Solaar](https://github.com/pwr-Solaar/Solaar) and Windows has the official Logitech client. We wanted a single-platform app that feels native, not a lowest-common-denominator port.

## Architecture at a glance

| Layer | Module | Responsibility |
|---|---|---|
| `OptuneCore` | Swift Package | Device registry, HID++ feature set, HID++ transport over IOKit |
| `OptuneApp` | App target | SwiftUI menu-bar + Settings, per-app profile engine, remap engine, notifications |
| `optune` | CLI | Scriptable wrapper around OptuneCore for diagnostics and headless use |

The split means everything you can do in the UI you can also do from a script — `optune battery`, `optune dpi --set 1600`, `optune doctor`. The CLI uses the same `DeviceRegistry` and `HIDPP` types the app uses.

## How it talks to devices

Most Logitech peripherals expose two HID interfaces over Bluetooth or the Logi Bolt receiver: a standard mouse/keyboard report and a **HID++ "long" report (0x11)** that carries everything else. Optune opens the HID++ interface using **IOHIDManager**, sends a 20-byte feature request, and parses the 20-byte reply.

There's no need for a kernel extension because IOKit gives userspace processes the right to claim a HID++ interface as long as **Input Monitoring** is granted. Optune asks for the permission once on first launch, links you straight to the right pane in System Settings, and then never asks again.

## Where to start

- New here? [Install](install.html) takes 30 seconds — Homebrew or DMG.
- Already running it? [Quickstart](quickstart.html) walks you through your first remap.
- Curious about a specific feature? Pick it from the sidebar — every HID++ feature has its own page with the report layout, capabilities, and quirks.
- Want to ship a contribution? [Build from source](building.html) and [adding a device](adding-a-device.html) are one-file PRs.
