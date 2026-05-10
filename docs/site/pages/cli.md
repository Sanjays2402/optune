---
title: CLI reference
section: Reference
order: 200
description: The optune CLI is the same code path as the GUI — every feature is scriptable.
lede: Every feature in Optune ships with a CLI command. The GUI and the CLI both call OptuneCore, so anything you can click you can also script.
---

# CLI reference

## Install

The CLI ships inside the app bundle at `Optune.app/Contents/Resources/optune`. The Homebrew cask symlinks it into `/opt/homebrew/bin/optune` automatically. If you used the DMG, run:

```bash
sudo ln -sf /Applications/Optune.app/Contents/Resources/optune /usr/local/bin/optune
```

## Commands

### `optune devices`

List every Logitech device IOKit can see, with HID++ feature support.

```
optune devices
optune devices --json
```

Output: name, transport (BLE / USB / RF), HID++ version, supported feature IDs.

### `optune doctor`

Diagnostic dump. Lists every HID interface, attempts a feature-set query on each, and prints permission state.

```
optune doctor
```

Run this first when something doesn't work.

### `optune battery`

```
optune battery
optune battery --device "MX Master 3S"
optune battery --json
```

### `optune dpi`

```
optune dpi                          # show current + range
optune dpi --set 1600               # set to 1600 DPI
optune dpi --device "MX Master 3S" --set 4000
```

### `optune smartshift`

```
optune smartshift                   # show state
optune smartshift --enable
optune smartshift --disable
optune smartshift --threshold 60    # 1..255
```

### `optune buttons`

```
optune buttons                          # list controls + bindings
optune buttons --catalog                # full action catalog
optune buttons --bind back=mission_control
optune buttons --reset-all
```

### `optune hosts`

```
optune hosts
optune hosts --switch 2
```

### `optune onboard`

```
optune onboard                       # show mode + slot
optune onboard --mode host
optune onboard --mode onboard
optune onboard --slot 1
```

### `optune backlight`

```
optune backlight
optune backlight --mode reactive --level 60
```

### `optune fnlock`

```
optune fnlock --enable
optune fnlock --disable
```

## Global flags

| Flag | Effect |
|---|---|
| `--device <name>` | Target a specific device when you have multiple. Matches a substring of the model name. |
| `--json` | Emit machine-readable JSON instead of pretty text. Stable across versions — write your scripts against this. |
| `--verbose` | Log every HID++ frame to stderr. Useful when filing a bug. |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic failure (HID++ error, device not found) |
| 2 | Permission denied (Input Monitoring not granted) |
| 3 | Feature not supported on this device |

## Scripting examples

**Notify when battery drops below 15%:**

```bash
#!/bin/bash
pct=$(optune battery --json | jq -r '.[0].percent')
if (( pct < 15 )); then
  osascript -e "display notification \"Battery $pct%\" with title \"Mouse\""
fi
```

**Daily report into your timeseries database:**

```bash
optune battery --json | curl -X POST -d @- https://your-tsdb/ingest
```
