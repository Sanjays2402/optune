---
title: Building from source
section: Reference
order: 230
description: Clone, build, bundle, and run Optune locally. Requires macOS 15+ and Swift 6.0+.
lede: Optune is a Swift Package — clone, swift build, done. The bundling step that produces Optune.app is one shell script.
---

# Building from source

## Requirements

- macOS 15 or newer (macOS 26 unlocks Liquid Glass)
- Xcode 16 with the **macOS 15 SDK** — full Xcode, not just Command Line Tools, because XCTest is needed for `swift test`
- Swift 6.0+

> If you only have Command Line Tools, `swift build` works fine for the app and CLI, but `swift test` fails with `no such module 'XCTest'`. CI on `macos-15` has the full SDK.

## Clone & build

```bash
git clone https://github.com/Sanjays2402/optune.git
cd optune
swift build
swift run optune doctor
```

A debug build takes ~3 seconds on an M1. A release build takes ~8 seconds.

## Run the menu-bar app

The `swift run` flow only works for the CLI — the menu-bar app needs a real `.app` bundle so AppKit can register itself with the Dock and so the menu-bar status item works. There's a one-shot bundling script:

```bash
swift build -c release
bash Scripts/bundle-app.sh release
open .build/OptuneApp.app
```

`bundle-app.sh` produces:

```
.build/OptuneApp.app/
  Contents/
    Info.plist
    MacOS/OptuneApp                  # universal binary
    Resources/
      optune                          # CLI symlink
      AppIcon.icns
      Assets.car
      en.lproj/Localizable.strings
```

The bundle is **ad-hoc signed** automatically by Swift. It runs on your machine without a Developer ID.

## Tests

```bash
swift test                          # full suite
swift test --filter DeviceRegistryTests  # one suite
```

Suites:

- `OptuneCoreTests` — HID++ frame parser, feature decoders, device-matching logic
- `DeviceRegistryTests` — registry validation (uniqueness, ranges, capability ↔ feature ID)
- `RemapEngineTests` — action catalog mapping, profile fallback logic

## Continuous integration

`.github/workflows/ci.yml` runs on `macos-15`. It:

1. Caches `~/.swiftpm` and `.build`
2. Runs `swift build -c debug -c release`
3. Runs `swift test`
4. Builds the release bundle and uploads it as a workflow artifact

Branch protection on `main` requires the `build (macos-15)` check to pass with linear history.

## Releases

Pushing a tag like `v0.6.1` triggers `.github/workflows/release.yml`:

1. Runs the same build + test
2. Bundles `Optune.app`
3. Wraps it in a universal DMG via `create-dmg`
4. Generates the SHA-256
5. Uploads the DMG and the cask manifest to GitHub Releases
6. Triggers `bump-tap.yml` in the homebrew-optune repo with the new version + SHA — the cask updates automatically

The full pipeline runs in about 5 minutes.

## Where to look

| You want to | Look at |
|---|---|
| Add an HID++ feature decoder | `Sources/OptuneCore/HIDPP/Features/` |
| Add a Settings pane | `Sources/OptuneApp/SettingsWindow.swift` |
| Add an action to the catalog | `Sources/OptuneApp/ActionCatalog.swift` |
| Tweak the menu-bar UI | `Sources/OptuneApp/MenuBar/` |
| Fix the bundling script | `Scripts/bundle-app.sh` |
| Update the device registry | `Sources/OptuneCore/Resources/devices.json` |
