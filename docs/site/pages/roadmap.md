---
title: Roadmap
section: About
order: 300
description: What's shipped, what's next, what's on the wishlist.
lede: Three columns — shipped, in flight, on the wishlist. Optune isn't done; the Logi parity gap is closing one feature per minor release.
---

# Roadmap

## Shipped

| Version | Headline |
|---|---|
| **v0.5** | Per-app profiles, keyboard backlight + Fn-lock, onboard mode, settings export/import, welcome flow, in-app updates |
| **v0.6** | Homebrew tap (`sanjays2402/optune`) with auto-bump, Accessibility (TCC) gate fix, sidebar Settings, eight HID++ features, custom button remap, in-app updater, GitHub Releases poller |
| **v0.7** | Action Catalog with 40+ named actions, single-instance guard, RemapActionDispatcher singleton bridge |

## In flight (v0.8)

- **SmoothScroll (`0x2121`)** — high-resolution scroll wheel events for fine in-app adjustment
- **Onboard slot writes** — push DPI / button bindings into onboard slots so the mouse keeps your config when plugged into a host without Optune
- **Gesture button state machine** — multi-direction gesture chords (currently we only divert single events)
- **Search bar in catalog menu** — 40+ actions deserves filterable selection in Settings → Buttons

## Wishlist (v1.0+)

- **Apple Developer ID + notarisation** — so TCC grants survive upgrades, no more re-toggle dance after `brew upgrade --cask optune`
- **Localised strings** — start with German, French, Japanese; Optune already wraps every UI string in `String(localized:)`
- **Optune Lite (CLI-only Homebrew formula)** — `brew install optune` for the headless / server crowd; ships only the CLI, no .app bundle
- **More devices** — every PR-able registry entry welcome (see [adding a device](adding-a-device.html))
- **Linux port?** — *No.* Solaar is excellent. Optune is Mac-only on purpose.

## Anti-roadmap

Things that will never ship in Optune:

- **Telemetry / analytics** — not anonymised, not opt-in, not "for stability metrics". None.
- **Account login** — pair the device, configure it, done.
- **Cloud profile sync** — JSON export / import is the sync mechanism. iCloud Drive handles the rest.
- **Auto-update background daemon** — the in-app updater asks before downloading. No LaunchAgents.
- **Cross-platform UI framework** — every line of UI is SwiftUI. If a feature is awkward in SwiftUI, we make SwiftUI work, not paper over it with Electron.
