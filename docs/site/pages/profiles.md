---
title: Per-app profiles
section: Features
order: 170
description: Optune flips DPI, SmartShift, scroll mode, and button bindings when you switch focus. Powered by NSWorkspace activation observers.
lede: One global profile, plus an unlimited number of per-app overrides. The flip happens the instant you Cmd-Tab — no polling, no daemon, no reload.
---

# Per-app profiles

## How it works

Optune subscribes to `NSWorkspace.shared.notificationCenter` for `didActivateApplicationNotification`. Each time a different app comes to the front, the notification handler runs:

```swift
let bundleID = app.bundleIdentifier ?? ""
let profile = profileStore.profile(for: bundleID) ?? globalProfile
deviceModel.apply(profile)
```

`apply(profile)` is the same code path the Settings UI uses to push a new value, so there's no special "profile flip" pipeline to break. Whatever the UI can change, profiles can override.

## What a profile holds

A profile is a Swift struct with optional fields. **Only fields you set get applied.** Anything left nil falls back to the global profile.

| Field | What it overrides |
|---|---|
| `dpi: Int?` | The active DPI preset value. |
| `smartShiftEnabled: Bool?` | Whether SmartShift is on. |
| `smartShiftThreshold: UInt8?` | The threshold value if SmartShift is on. |
| `scrollMode: ScrollMode?` | Forces ratchet, free-spin, or smart. |
| `bindings: [Control: RemapAction]?` | Per-button overrides for this app. |

The store is `~/Library/Application Support/Optune/profiles.json`, keyed by bundle ID. You can edit the JSON directly if you want — Optune watches the file with a Dispatch source and reloads on change.

## Common patterns

**Final Cut Pro / Logic Pro** — boost DPI and force ratchet for precise scrubbing:

```json
{
  "com.apple.FinalCut": {
    "dpi": 6400,
    "scrollMode": "ratchet",
    "smartShiftEnabled": false
  }
}
```

**Safari / Chrome** — bind the back button to "Back" (instead of Mission Control):

```json
{
  "com.apple.Safari": {
    "bindings": {
      "back": { "kind": "keystroke", "keyCode": 123, "modifiers": ["cmd"] }
    }
  }
}
```

**Xcode** — heavy keystroke sets (Build, Run, Stop) on the gesture button:

```json
{
  "com.apple.dt.Xcode": {
    "bindings": {
      "gesture_up": { "kind": "keystroke", "keyCode": 11, "modifiers": ["cmd"] }
    }
  }
}
```

## Debouncing

Cmd-Tab between two apps fast and macOS fires multiple activation events in milliseconds. Optune debounces with a 50 ms window — only the **last** activation in any 50 ms burst triggers a profile flip. This keeps the firmware from getting hammered.

## Picker

Settings → **Per-App Profiles** → **+** opens a system app picker. The picker filters to running + installed apps and remembers your last choice. Bundle IDs are stored — renaming or moving the app doesn't break the profile.

## Export / import

Cmd-Shift-E exports your **entire** Optune state — global profile, all per-app profiles, button bindings, presets — to a JSON file. Cmd-Shift-I imports one. Useful for migrating to a new Mac without reconfiguring.
