---
title: Permissions & TCC
section: Start
order: 40
description: How Optune uses Input Monitoring and Accessibility, what each unlocks, and how to recover after a code-sign change invalidates them.
lede: macOS gates HID and synthetic input behind two separate Transparency, Consent, and Control (TCC) prompts. Here's exactly what each unlocks and how to recover when an upgrade invalidates them.
---

# Permissions & TCC

## The two prompts

Optune asks for **Input Monitoring** and **Accessibility**. They sound similar; they aren't.

| Permission | Surface | Without it |
|---|---|---|
| **Input Monitoring** | All HID++ feature reads/writes — battery, DPI, SmartShift, button enumeration, host switching, backlight, Fn-lock, onboard mode. | The app launches but every device shows "?" for battery and the Settings panes are empty. |
| **Accessibility** | Synthesized keystrokes (`keystroke`), mouse clicks (`mouseClick`), and media keys (`mediaKey`) — i.e. button remap actions that have to forge events. | DPI presets, SmartShift, hosts still work. Custom button bindings that produce real key events don't. The Buttons pane shows a banner. |

## Why two separate boundaries

macOS has been splitting "watch what the user is doing" from "act on the user's behalf" since macOS 10.15. Input Monitoring is the read-side gate — it lets us see and talk to HID interfaces. Accessibility is the write-side gate — it lets us forge events into the system.

If Apple ever folds them together you'll just see one prompt; until then we ask for the smaller permission first and the larger one only when a feature actually needs it.

## Recovering after a re-sign

The first time it'll bite you is the first upgrade. Each time the Optune binary is **code-signed** the OS treats it as a new identity, and TCC throws out the old grant. You'll see:

- Battery pills go to "?"
- Buttons stop responding to remaps

Fix it once and it sticks until the next re-sign:

1. Open **System Settings → Privacy & Security → Input Monitoring**
2. Find **Optune**. If it's checked, **uncheck and re-check** it.
3. Repeat for **Accessibility** if you use button remap.

Optune ships an **AccessibilityChecker** that runs on every launch — if either grant is stale you'll see a banner with a one-click jump button straight to the right pane. v0.6 added the same check for Input Monitoring after `OPTU-22` reported the silent failure.

> **Future fix:** once we have an Apple Developer ID + notarisation (paid Developer Program), the binary identity stops shifting between releases and TCC remembers it across upgrades. Until then, expect the dance once per release.

## Headless / CI

The `optune` CLI uses the same `IOHIDManager` path, so it also needs Input Monitoring. On a headless host (no Login window, no Finder), the standard workflow is:

```bash
sudo tccutil reset SystemPolicyAllFiles ~/Library/Application\ Support/com.apple.TCC/TCC.db
# Then run `optune doctor` once interactively to trigger the prompt.
```

Once granted, the grant survives reboots. There is no LaunchAgent — `optune` is invoked on demand.
