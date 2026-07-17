# Optune

A native macOS replacement for Logitech Options+, written in Swift 6.

Optune configures Logitech MX mice and keyboards over HID++ — battery, DPI, SmartShift, button remapping, multi-host switching, and keyboard backlight — without accounts, telemetry, background daemons, or ads. It ships as a single menu bar app plus an `optune` CLI, both driven by IOKit HIDManager (no kernel extensions).

```sh
brew tap sanjays2402/optune
brew install --cask optune
```

Inspired by [Solaar](https://github.com/pwr-Solaar/Solaar) and [logitune](https://github.com/mmaher88/logitune); a clean-room implementation that shares no code with either.

## Features

- **Battery** — live level, charging state, and history
- **Pointer** — adjustable DPI and SmartShift threshold
- **Buttons** — full control enumeration and runtime remapping
- **Hosts** — multi-host pairing readout and switching
- **Keyboard** — backlight control and Fn-lock
- **Profiles** — per-app settings that follow the focused application
- **Onboard** — host vs onboard mode and slot selection
- Menu bar app with live telemetry, sidebar settings, low-battery notifications, and in-app update checks

See the [CHANGELOG](CHANGELOG.md) and [Releases](https://github.com/Sanjays2402/optune/releases) for the current feature set and version details.

## Requirements

- macOS 15 or later (macOS 26 enables the Liquid Glass material)
- **Input Monitoring** permission for HID++ requests; **Accessibility** permission for keystroke remap actions. Optune prompts for both on first use.

## Install

**Homebrew (recommended):**

```sh
brew tap sanjays2402/optune
brew install --cask optune
```

**Manual:** download the latest DMG from [Releases](https://github.com/Sanjays2402/optune/releases/latest) and drag Optune.app to `/Applications`. The build is ad-hoc signed, so the first launch requires right-click → **Open** to bypass Gatekeeper.

## CLI

```sh
$ optune battery
MX Master 3S — 78%, discharging (Bluetooth)

$ optune dpi 6400
MX Master 3S — applied 6400 dpi

$ optune smartshift --off
MX Master 3S — SmartShift disabled
```

Commands: `devices`, `doctor`, `battery`, `dpi`, `smartshift`, `buttons`, `hosts`.

## Build from source

Requires macOS 15+ and Swift 6.0+.

```sh
git clone https://github.com/Sanjays2402/optune.git
cd optune
swift build -c release
swift test
bash Scripts/bundle-app.sh release   # produces .build/OptuneApp.app
```

## Architecture

One `Package.swift`, five products sharing a common core:

- `OptuneCore` — IOKit HID, HID++ transport, features, device registry
- `OptuneUI` — shared design system
- `OptuneCLI` — the `optune` command
- `OptuneApp` — SwiftUI menu bar app and settings
- `OptuneShowcase` — screenshot/marketing window (not the production app)

A new HID++ feature added to `OptuneCore` is available in every surface.

## Contributing

Issues and PRs welcome. Run `swift build` and `swift test` before submitting.

Adding a device is a one-file change to [`Sources/OptuneCore/Resources/devices.json`](Sources/OptuneCore/Resources/devices.json) with no Swift edits — see [docs/adding-a-device.md](docs/adding-a-device.md). To report an unsupported device, run `optune devices --json --all` and open an issue with the output.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE). HID++ 2.0 was reverse-engineered by the Solaar, logiops, and libratbag communities.
