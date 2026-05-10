---
title: Troubleshooting
section: Reference
order: 240
description: Common Optune problems and how to fix them — battery shows ?, button remap not firing, device missing.
lede: Most issues fall into one of five buckets. Skim the headings, find your symptom, fix it. If yours isn't here, optune doctor is the right next step.
---

# Troubleshooting

## "Battery shows ?"

Means the HID++ feature call timed out or the firmware returned `0xFF`.

1. **Check Input Monitoring.** System Settings → Privacy & Security → Input Monitoring → Optune is checked. If unchecked, toggle it; if checked, **uncheck and re-check** to refresh the TCC grant after an upgrade.
2. **Check the device pairing.** Some BLE devices renegotiate after wake. Move the mouse, wait 5 seconds, watch the pill.
3. **Check `optune doctor`.** It dumps every HID interface IOKit knows about. If your device is listed but `featureSet` is empty, it's a HID++ handshake failure — usually a firmware quirk on the older MX Master 2S.

## "Button remap doesn't fire"

The button physically clicks but nothing happens in macOS.

1. **Check Accessibility.** System Settings → Privacy & Security → Accessibility → Optune. Required for `keystroke`, `mouseClick`, and `mediaKey` actions.
2. **Are you in onboard mode?** Onboard mode honours the device's flash bindings, not Optune's. Switch to host mode in Settings → Onboard.
3. **Did the divert ack fail?** Run with `--verbose` and look for `setRemap … divert=1` followed by `INVALID_ARGUMENT`. Some buttons on some firmwares refuse divert — Optune greys those rows out, but a stale UI cache might still show them as bindable.

## "DPI presets aren't applying"

The slider moves but the cursor speed doesn't change.

1. **Onboard mode** — same as above. Onboard mode locks DPI.
2. **Per-app override** — check Settings → Per-App Profiles. The active app's profile may pin DPI to a value distinct from the global slider.
3. **Driver conflict** — if you have **Logi Options+** installed, it can race Optune for the HID++ interface. Quit Options+ entirely (`launchctl unload` + `pkill -i logi`) before testing.

## "Device disappears after wake"

macOS occasionally drops BLE devices on wake. Optune subscribes to `IOHIDManager` re-attach events, so the device should reappear within seconds. If it doesn't:

1. Wiggle the mouse — BLE wake-on-motion takes a frame.
2. **Forget and re-pair** in System Settings → Bluetooth. Some firmwares get into a bad bond state after sleep / wake on multiple hosts.

## "App won't open after upgrade"

If macOS shows "Optune is damaged and can't be opened":

```bash
xattr -d com.apple.quarantine /Applications/Optune.app
```

The DMG is ad-hoc signed (no Developer ID). Gatekeeper sometimes flags re-signed apps after the first launch. Removing the quarantine xattr fixes it without compromising security — you're still launching the same hash you downloaded.

## Filing a bug

Run `optune doctor --verbose 2>&1 | tee optune-doctor.log` and attach the log. Include:

- Optune version (`optune --version`)
- macOS version (`sw_vers`)
- Device name and connection (BLE / Bolt / USB cable)
- Repro steps

[Open an issue](https://github.com/Sanjays2402/optune/issues/new) — I read every one.
