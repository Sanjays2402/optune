# Security Policy

## Supported versions

Security fixes go into the latest release. Please update before reporting.

## Reporting a vulnerability

**Please don't open a public issue for security problems.** Use GitHub's private reporting instead:
<https://github.com/Sanjays2402/optune/security/advisories/new>

Include what you found, the version, steps to reproduce, and the impact you think it has. You'll get an acknowledgement as soon as the maintainer can respond (this is a one-person, volunteer project), and we'll work with you on a fix and a coordinated disclosure date. Good-faith research that avoids harming other people's systems and data is welcome.

## Things to know

- **Shell-command remaps run as you.** A button bound to _Run shell command_ executes that command with your user privileges. A settings file can contain such bindings, so **only import settings from sources you trust.**
- **Permissions.** Optune asks for Input Monitoring (to talk to Logitech HID++ interfaces) and Accessibility (to send keystrokes for remaps). It does not log what you type.
- **Network.** The only request Optune makes is the update check described in the [Privacy Policy](PRIVACY.md).
- **Builds are ad-hoc signed and not notarized.** Verify the SHA-256 checksum published with each release.

## Scope

In scope: the Optune app, CLI, the release and CI workflows, and the website. Out of scope: vulnerabilities in a device's own firmware, macOS, or third-party tools — report those to their vendors.
