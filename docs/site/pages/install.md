---
title: Install
section: Start
order: 20
description: Install Optune via Homebrew or download the DMG. Set up Input Monitoring and Accessibility permissions.
lede: Two install paths — both finish in under a minute. Pick Homebrew if you already use it, the DMG if you don't.
---

# Install

## Homebrew (recommended)

```bash
brew tap sanjays2402/optune
brew install --cask optune
```

The cask lives at [`Sanjays2402/homebrew-optune`](https://github.com/Sanjays2402/homebrew-optune) and auto-bumps on every GitHub release thanks to a tap-bump workflow that runs as soon as the DMG is published. Upgrades are normal `brew upgrade --cask optune`.

## Direct download

1. Grab the latest universal DMG from [Releases](https://github.com/Sanjays2402/optune/releases/latest)
2. Mount it and drag **Optune.app** to `/Applications`
3. The build is **ad-hoc signed** (we don't have an Apple Developer cert yet), so the first launch needs **right-click → Open** to bypass Gatekeeper. After that double-click works.

## Permissions

Optune needs two macOS permissions. The welcome flow links you straight to the correct System Settings pane on first launch — you don't have to hunt.

| Permission | Why | When asked |
|---|---|---|
| **Input Monitoring** | Send HID++ feature requests over IOKit | On first launch |
| **Accessibility** | Send synthesized keystrokes for button remap | On first remap that uses `keystroke`, `mouseClick`, or `mediaKey` |

If you skip Accessibility you can still use battery, DPI, SmartShift, hosts, onboard, and backlight. You just can't remap a button to **Cmd+C**. The Settings → Buttons pane shows a banner telling you so.

> **Why two permissions?** Input Monitoring lets Optune talk to the device. Accessibility lets Optune *act on your behalf* — those are different trust boundaries on macOS and Apple keeps them separate.

## Uninstall

```bash
brew uninstall --cask optune
brew untap sanjays2402/optune
```

If you installed from the DMG, drag `Optune.app` to the Trash and remove its preferences:

```bash
defaults delete com.sanjays2402.optune
rm -rf ~/Library/Application\ Support/Optune
```

There is no daemon, no LaunchAgent, no helper tool — uninstalling is just deleting the app.

## Requirements

- macOS 15 (Sequoia) or newer
- A Logitech device that speaks HID++ 2.0 over Bluetooth or a Logi Bolt receiver

The Liquid Glass material is available on **macOS 26**; on 15 you get composited materials that look almost identical. No feature is gated by OS version.
