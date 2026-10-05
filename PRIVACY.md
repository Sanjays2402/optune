# Privacy Policy

_Effective 5 October 2026_

**Short version:** Optune does not collect, sell, or share personal data. It has no accounts, no analytics, no advertising and no crash reporting. Everything it knows stays on your Mac, apart from one optional request to GitHub to check for updates.

This policy covers the Optune app and `optune` command-line tool ("Optune") and the project website at <https://sanjays2402.github.io/optune/> (the "Website"). "We" means the Optune maintainer, Sanjay Santhanam.

## 1. What Optune stores on your Mac

Optune keeps its settings in a single JSON file at `~/Library/Application Support/Optune/devices.json`. It can contain:

- your devices' product IDs and serial numbers (used to tell devices apart),
- device nicknames, DPI stages, SmartShift, wheel and button settings,
- button and gesture remaps — including any shell commands you assign,
- per-app profiles (the bundle identifiers of apps you choose),
- up to 14 days of battery readings, and your notification preferences.

This file never leaves your Mac unless you export it yourself (File → Export Settings…). You can delete it at any time; Optune will start fresh.

## 2. What Optune sends over the network

Optune makes **one** kind of network request: an update check.

- **What:** a `GET` request to `https://api.github.com/repos/Sanjays2402/optune/releases/latest` with the user-agent `optune-update-checker`.
- **When:** about five seconds after launch, then once a day while the app is running, and when you choose _Check for Updates…_ It can be switched off in Settings → Updates.
- **Who sees it:** GitHub, which receives your IP address and the request headers as with any web request, and handles them under [GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement). We do not receive this information.

Optune sends nothing about your devices, settings, usage or identity to us or to anyone else. The command-line tool makes no network requests.

## 3. System permissions

macOS asks you to approve these; Optune uses them only for the stated purpose.

| Permission | Why Optune needs it |
|---|---|
| **Input Monitoring** | To open your Logitech device's HID++ interface and read/write its settings. Optune only talks to Logitech HID++ interfaces. It does not record, store or transmit what you type or click. |
| **Accessibility** | Only for button remaps that send keystrokes, mouse clicks or media keys on your behalf, and to detect which app is in front for per-app profiles. |
| **Notifications** | Local low-battery, connection and host-switch alerts. Nothing is sent to a server. |

You can revoke any of these in System Settings → Privacy & Security.

## 4. The Website

The Website is hosted on GitHub Pages. GitHub may log visitors' IP addresses and request details under its own policies. The Website does not use cookies, analytics, advertising, or third-party scripts or fonts. The documentation pages remember your light/dark preference in your browser's local storage; it stays on your device.

## 5. Downloads and package managers

When you download Optune from GitHub Releases or install it with Homebrew, those services handle the transfer under their own privacy policies. We do not receive download identities.

## 6. Children

Optune is a utility for configuring computer peripherals and is not directed to children. We do not knowingly collect data from anyone.

## 7. Your rights

Because we do not collect or hold personal data about you, there is nothing for us to access, correct, port or delete. If local data worries you, you can inspect or delete the settings file described in section 1. Requests relating to GitHub's logs must go to GitHub.

## 8. Changes

If this policy changes, the new version will be published in the repository with a new effective date and noted in the [changelog](CHANGELOG.md). Optune's behaviour regarding data will not become more invasive without a prominent notice in the release notes.

## 9. Contact

Questions about this policy: open an issue at <https://github.com/Sanjays2402/optune/issues>. For anything sensitive, use a [private security advisory](https://github.com/Sanjays2402/optune/security/advisories/new).
