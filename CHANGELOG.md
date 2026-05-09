# Changelog

All notable changes to Optune are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning is [SemVer](https://semver.org/).

## [Unreleased] — v0.4 wide-feature surface

### Added — HID++ features
- Feature `0x0003` **DeviceFwVersion** — entity count, per-entity firmware string with prefix/version/build.
- Feature `0x0005` **DeviceTypeName** — device kind (mouse/keyboard/etc) and friendly model name from the firmware.
- Feature `0x0007` **DeviceFriendlyName** — user-set nickname read/write.
- Feature `0x1814` **ChangeHost** — query host count + active host, switch host atomically.
- Feature `0x1815` **HostsInfo** — per-slot host descriptor (BT name, paired vs not, last seen).
- Feature `0x8100` **OnboardProfiles** — read profile mode, count, slot metadata (groundwork for 0.5 profile editing).
- Feature `0x2121` **HiResWheel** — capability bits, resolution multiplier, ratchet engage/free-spin toggle, wheel-inversion preference.
- Feature `0x2205` **PointerSpeed** — 8.8 fixed-point multiplier read/write (clamped 0.5×–4.0×).
- Feature `0x1D4B` **WirelessDeviceStatus** — link state + transport hint without re-enumerating.

### Added — CLI
- `optune firmware`, `optune name`, `optune nickname`, `optune hosts`, `optune host-switch`,
  `optune profiles`, `optune wheel`, `optune speed` — 8 new subcommands, all with `--json`
  + `--pid` and the same TCC error story as `optune battery`. (`optune reset` deferred to
  v0.5 alongside profile editing.)

### Added — App
- **Settings persistence** (`~/Library/Application Support/Optune/settings.json`): preferred
  DPI, SmartShift state, pointer-speed multiplier, wheel ratchet, nickname, low-battery
  threshold, login-item state, and a 60-sample battery ring buffer per device.
- **Low-battery notifications** via `UserNotifications` — fire once per drain cycle, reset
  on charge. Threshold and on/off control surfaced in the new General pane.
- **Sleep/wake observer** — re-polls all devices on `NSWorkspace.didWakeNotification` so
  battery & link state are fresh after the lid opens.
- **Login item** via modern `SMAppService.mainApp` (no legacy `LSSharedFileList`).
- **New Settings panes**: Wheel (ratchet + multiplier + invert), Hosts (slot list +
  switch-host confirmation dialog), General (notifications, login-item, factory reset).
- **About pane** — now live: shows firmware version, device type, friendly name from the
  feature reads instead of static placeholder copy.
- **Battery sparkline** — Path-rendered ring buffer chart in each device card.
- **Menu-bar label** — battery % now appears next to the mouse glyph (red ≤15%, orange
  ≤30%, lightning bolt while charging).
- **Procedural app icon** — generated at all 9 sizes via SwiftUI/CoreGraphics
  (`scripts/generate_appicon.swift` → `Resources/AppIcon.iconset` → `AppIcon.icns`).
  No raster assets checked in beyond the generated outputs.

### Changed
- Bundle script now bumps `CFBundleShortVersionString` to `0.4.0` and references the
  procedural `AppIcon.icns` if present.

### Known limitations
- The same Input Monitoring TCC requirement still applies — every new feature degrades
  to a clear "Input Monitoring required" pill rather than silently breaking.
- 0x8100 OnboardProfiles is **read-only** in 0.4 (slot listing only). Profile editing
  lands in 0.5.

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
- **Menu bar app**: live battery row replaces the old "pending HID++" placeholder.
  Polls every 60s in the background, refreshes immediately when the user clicks
  Refresh, and shows a tinted icon (red <20%, green when charging) plus charging /
  plugged-in state. On TCC denial it surfaces an actionable hint inline rather than
  silently spinning.

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
