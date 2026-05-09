# Optune

Configure Logitech devices on macOS — an open-source alternative to Logitech Options+, built natively for Apple Silicon.

> **Status: v0.1.0 — early scaffold.** Device enumeration works. HID++ feature negotiation, battery, DPI, button remap, and per-app profiles are on the roadmap.

Inspired by [logitune](https://github.com/mmaher88/logitune) (Linux) and [Solaar](https://github.com/pwr-Solaar/Solaar). Optune is a clean-room Swift implementation for macOS — it doesn't share code with either, but learns from their HID++ work.

## Why

Logitech Options+ is closed-source, ad-laden, runs background "Logi AI" services, and ships a fresh installer every time you blink. If you just want to remap your MX Master 3S buttons and see the battery level, you shouldn't need an account.

Optune is:
- Native macOS (Swift 6 + SwiftUI on macOS 15+, Liquid Glass on macOS 26+)
- A single signed `OptuneApp.app` plus an `optune` CLI
- IOKit HIDManager for device discovery — no kernel extensions, no daemons
- GPL-3.0, no telemetry, no account, no ads

## What works in v0.1.0

- ✅ `optune devices` — lists attached Logitech HID interfaces
- ✅ `optune devices --json` — machine-readable output
- ✅ `optune doctor` — readiness check (devices visible, descriptors matched, HID++ permissions)
- ✅ `OptuneApp` — SwiftUI menu bar app with Liquid Glass UI
- ✅ MX Master 3S descriptor (Bolt / Unifying / Bluetooth)

## Roadmap

| Milestone | Scope |
|-----------|-------|
| **v0.2** | HID++ 2.0 transport (short/long reports), feature index, battery (`0x1004`) |
| **v0.3** | DPI control (`0x2201`), SmartShift (`0x2110`), reprogrammable controls (`0x1B04`) |
| **v0.4** | Per-app profiles, gestures, smooth scroll toggle |
| **v0.5** | More devices: MX Master 3, MX Master 4, MX Anywhere 3S, MX Keys S |
| **v1.0** | Code-signed notarised universal release, Sparkle auto-update |

Battery / DPI / SmartShift currently render as `— pending HID++` in the UI — that's honest, not a stub bug.

## Install (from source)

Requires macOS 15+ and Swift 6.0+.

```bash
git clone https://github.com/Sanjays2402/optune.git
cd optune
swift build -c release
./.build/release/optune devices
./.build/release/OptuneApp        # menu bar app
```

Optune needs **Input Monitoring** permission to send HID++ feature requests. macOS will prompt the first time you run something that talks to the device. Granted? Re-run `optune doctor` to confirm.

## Architecture

```
optune/
├── Sources/
│   ├── OptuneCore/     # IOKit HID enumeration, HID++ constants, device registry
│   ├── OptuneCLI/      # `optune` command (devices, doctor)
│   └── OptuneApp/      # SwiftUI MenuBarExtra menu bar app
├── Tests/OptuneCoreTests/
└── .github/workflows/ci.yml   # macOS-15, swift build + test
```

Three Swift Package products from one `Package.swift`. CLI and app share `OptuneCore`, so adding a feature lights up in both.

## Contributing

Issues and PRs welcome. Please run `swift build` and `swift test` before submitting.

If you have a Logitech device that isn't in `Sources/OptuneCore/DeviceRegistry.swift`, the easiest way to help is to:

1. Run `optune devices --json --all` and share the output in an issue
2. Or open a PR adding a `DeviceDescriptor` for it

## License

GPL-3.0-or-later — see [LICENSE](LICENSE). Same as Logitune and Solaar so reverse-engineered HID++ knowledge stays in the same family.

## Credits

- HID++ protocol: reverse-engineered by the Solaar / logiops / libratbag communities over many years
- Inspiration: [logitune](https://github.com/mmaher88/logitune) by mmaher88
- This is a clean-room rewrite for macOS — no code copied
