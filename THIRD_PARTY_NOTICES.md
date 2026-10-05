# Third-party notices

Optune is licensed under the GNU GPL v3 or later (see [LICENSE](LICENSE)). This file lists the third-party software and material Optune uses or acknowledges.

## Software dependencies

| Component | Used by | Licence |
|---|---|---|
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) (≥ 1.5.0) © Apple Inc. and the Swift project authors | the `optune` CLI (source builds) | Apache License 2.0 |

The Apache-2.0 text is at <https://www.apache.org/licenses/LICENSE-2.0> and ships with the package's source when you build with SwiftPM. Apache-2.0 is compatible with GPL-3.0.

## Apple platform

Optune is built on macOS system frameworks (SwiftUI, AppKit, IOKit, CoreGraphics, UserNotifications, ServiceManagement). These are part of the operating system and are not redistributed. Symbols in the interface come from Apple's **SF Symbols**, used under the SF Symbols licence for in-app interface glyphs only. Optune's app icon and logo are **original artwork** and do not use SF Symbols.

## Protocol knowledge — no code copied

Optune talks to devices over Logitech's HID++ 2.0 protocol. Its decoders are original Swift written for this project. The protocol's behaviour is publicly documented by community reverse-engineering work, which Optune credits as reference material:

- [Solaar](https://github.com/pwr-Solaar/Solaar)
- [logiops](https://github.com/PixlOne/logiops)
- [libratbag](https://github.com/libratbag/libratbag)
- [hid-tools](https://gitlab.freedesktop.org/libevdev/hid-tools)

Design ideas (for example a categorised action catalogue) were inspired by [Mouser](https://github.com/TomBadash/Mouser), [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) and [Logitune](https://github.com/mmaher88/logitune). **No source code from these projects is included in Optune.** If you believe otherwise, please open an issue so it can be corrected.

## Fonts and web assets

The Optune website and documentation use only the visitor's system fonts and load no third-party scripts, fonts or analytics.

## Trademarks

See [TRADEMARKS](TRADEMARKS.md).
