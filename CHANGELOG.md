# Changelog

All notable changes to Optune are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning is [SemVer](https://semver.org/).

## [Unreleased] — v0.2 HID++ transport

### Added
- `HIDPPTransport` — async HID++ 2.0 transport over IOKit. 7-byte short and 20-byte
  long reports, software-id correlation, dispatch-queue scheduling (works in CLI without
  an active CFRunLoop), per-request timeouts, proper teardown via `IOHIDDeviceCancel`.
- Feature `0x0000` Root.GetFeature lookup (`Sources/OptuneCore/Features/Root.swift`).
- Feature `0x1004` UnifiedBattery (`Sources/OptuneCore/Features/UnifiedBattery.swift`)
  with `ChargingState` enum and external-power detection.
- `optune battery` CLI subcommand — opens the device, looks up Feature 0x1004 via Root,
  queries unified-battery status. `--json` and `--pid` flags supported.
- `optune doctor` now actually opens the device and round-trips a Root probe to detect
  TCC denial (Input Monitoring) — surfaces a clear actionable message rather than
  silently failing.
- `OPTUNE_HIDPP_DEBUG=1` environment flag dumps every TX/RX frame as hex for protocol
  debugging.

### Known limitations
- Requires **Input Monitoring** (System Settings → Privacy & Security → Input Monitoring)
  for the running binary. macOS attributes the request to the *responsible parent process*
  for child processes; spawn `optune` from Terminal/Finder or grant Input Monitoring to
  the parent.
- BLE-paired devices on macOS only expose the long-report (0x11) HID++ surface — short
  (0x10) requests are rejected with `IOReturn 0xE00002F0`. All current feature calls
  use long reports.

## [0.1.0] — 2026-05-09

### Added
- Swift Package with three products: `OptuneCore` library, `optune` CLI, and `OptuneApp` menu bar app.
- IOKit-based Logitech HID device enumeration (`HIDEnumerator.logitechDevices()`).
- Built-in MX Master 3S descriptor (Bolt 0xB034, Unifying 0x4082, Bluetooth 0x407B).
- HID++ usage-page constants and feature ID enum (`HIDPP.Feature`).
- `optune devices` CLI with human-readable and JSON output, plus `--all` filter toggle.
- `optune doctor` readiness check (devices visible, descriptors matched, HID++ reachable).
- SwiftUI MenuBarExtra app with Liquid Glass-styled menu, header card, device card, and capability rows.
- Settings window with Devices and About tabs.
- GitHub Actions CI workflow (macOS-15, `swift build` + `swift test`).
- XCTest suite covering device modeling, HID++ constants, descriptor lookup, and metadata.
- GPL-3.0-or-later license.
