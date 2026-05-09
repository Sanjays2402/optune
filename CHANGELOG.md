# Changelog

All notable changes to Optune are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning is [SemVer](https://semver.org/).

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
