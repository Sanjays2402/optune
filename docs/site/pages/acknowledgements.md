---
title: Acknowledgements
section: About
order: 310
description: People and projects that made Optune possible.
lede: Optune doesn't share code with any HID++ library, but it stands on a decade of reverse-engineering work by the Linux community. Credit where it's due.
---

# Acknowledgements

## HID++ reverse engineering

Optune's HID++ feature decoders are clean-room Swift, but the **specifications** they decode are the result of years of careful reverse-engineering work by:

- **[Solaar](https://github.com/pwr-Solaar/Solaar)** — the canonical Linux Logitech control suite. Their `lib/logitech_receiver/hidpp20.py` is the reference for what a feature ID does and how its capabilities map.
- **[logiops](https://github.com/PixlOne/logiops)** — a C++ daemon for Linux that taught me how `ReprogControlsV4` divert really works.
- **[hid-tools](https://gitlab.freedesktop.org/libevdev/hid-tools)** — the Python toolkit for capturing and replaying HID frames; invaluable for figuring out what a firmware actually sends.

If you use Linux, install Solaar. It's wonderful. Optune exists because macOS deserves something equivalent that doesn't run as a kernel extension.

## Mac-side inspiration

- **[Mouser](https://github.com/TomBadash/Mouser)** — the named action catalog idea (40+ presets across 8 categories) is directly inspired by Mouser's action picker. Optune's catalog is a fresh Swift implementation but the UX pattern is theirs.
- **[Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements)** — the gold standard for "how to do `CGEventTap` correctly on macOS". Optune's `RemapEngine` borrows the divert-then-synthesize pattern.
- **[Logitune](https://github.com/mmaher88/logitune)** — an earlier MX Master menu-bar utility that proved the IOKit HIDManager path works on macOS without elevated privileges.

## Tooling

- **[Sparkle](https://sparkle-project.org/)** isn't a dependency — Optune polls GitHub Releases directly to avoid the appcast plumbing. But the Sparkle docs are still the right reading material if you want to understand auto-update UX.
- **[create-dmg](https://github.com/create-dmg/create-dmg)** — produces the universal DMG in CI.
- **[Peekaboo](https://peekaboo.sh/)** — this docs site copies Peekaboo's design language. The structure (sidebar + content + TOC), the typography (Fraunces + JetBrains Mono), and the dark/light theme machinery are all theirs. We swapped the green ecto accent for macOS system blue.

## Thanks

Anyone who's filed an issue or sent a `devices.json` PR — that's how this project gets better. If your device works in Optune today, someone before you likely captured a feature dump and pushed it.
