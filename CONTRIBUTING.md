# Contributing to Optune

Thanks for helping! Issues and pull requests are welcome.

## Quick start

```sh
git clone https://github.com/Sanjays2402/optune.git
cd optune
swift build
swift test
```

Run `swift build` and `swift test` before opening a PR. CI also builds on macOS 15 and macOS 26.

## Adding a device

Adding a device is usually a one-file change to [`Sources/OptuneCore/Resources/devices.json`](Sources/OptuneCore/Resources/devices.json). See [docs/adding-a-device.md](docs/adding-a-device.md). Run `optune devices --json --all` and include the output in your issue or PR.

## Licence of contributions

Optune is GPL-3.0-or-later. By submitting a contribution you agree that it is licensed under the same terms (inbound = outbound), and you certify the [Developer Certificate of Origin 1.1](https://developercertificate.org/): that you wrote it or otherwise have the right to submit it under this licence. Sign your commits with `git commit -s` to say so.

## Keep the project clean

To keep the project safe for everyone:

- **Original work only.** Don't paste in code you didn't write or can't relicense under GPL-3.0-or-later. Don't copy code from other Logitech tools (Solaar, logiops, etc.); read their documentation for behaviour and write your own implementation.
- **No proprietary material.** No Logitech software, firmware, logos or artwork, and no leaked or confidential specifications. Device information must come from your own device or public sources.
- **No new network calls or tracking** without prior discussion — Optune's privacy promise is part of the product.
- **Assets.** Only add images, fonts or icons you made or that have a licence allowing redistribution; say where they came from in the PR. Don't use SF Symbols in logos or icons.

## Conduct

Be kind. See the [Code of Conduct](CODE_OF_CONDUCT.md).
