# Terms of Use

_Effective 5 October 2026_

These terms apply to the Optune app and `optune` command-line tool ("Optune"), its source code, and the project website at <https://sanjays2402.github.io/optune/>. By downloading, installing or using Optune you agree to them. If you don't agree, don't use Optune.

## 1. The licence comes first

Optune is free software released under the **GNU General Public License, version 3 or later** ([LICENSE](LICENSE)). You may run, study, share and modify it under that licence. **Nothing in these terms takes away any right the GPL gives you**, and if these terms conflict with the GPL about your rights to the code, the GPL prevails. These terms add practical rules for using the software and website and explain the risks.

## 2. No warranty

THERE IS NO WARRANTY FOR OPTUNE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. OPTUNE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF OPTUNE IS WITH YOU. (This restates sections 15–17 of the GPL.)

## 3. Limitation of liability

TO THE EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT WILL THE MAINTAINER OR ANY CONTRIBUTOR BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE OPTUNE, INCLUDING LOSS OF DATA, LOSS OF DEVICE SETTINGS, OR DEVICE MALFUNCTION, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

## 4. You are changing real hardware settings

Optune sends HID++ commands that read and change settings stored on your devices — DPI, SmartShift, button diversion, onboard profiles, host switching, names and, if you choose it, a factory reset. Mistakes or firmware quirks can lose settings, require re-pairing, or make a device behave unexpectedly. Optune is not made, endorsed or tested by the device manufacturer, and using it may be outside the manufacturer's warranty terms. Check your warranty and back up anything important first.

## 5. Your responsibilities

- **Remaps run with your privileges.** A button or gesture bound to _Run shell command_ executes that command as you. Only enter commands you understand.
- **Only import settings you trust.** A settings file can contain shell-command remaps. Importing one from an untrusted source can run commands you did not write.
- **Grant permissions deliberately.** Input Monitoring and Accessibility are powerful; see the [Privacy Policy](PRIVACY.md) for exactly how Optune uses them.
- **Follow the law and other agreements.** You are responsible for complying with applicable law, your employer's or school's policies, and any terms attached to your devices or the manufacturer's own software.
- **Verify what you install.** Download Optune only from the [official repository](https://github.com/Sanjays2402/optune) or Homebrew tap. Release builds are ad-hoc signed, **not notarized**, and each release lists SHA-256 checksums.

## 6. Acceptable use

Do not use Optune, or the Website, to break the law, to infringe anyone's rights, to attack or interfere with devices or networks you don't own or have permission to test, or to harass the maintainers or other users. Do not present a modified build as the official Optune: if you distribute a modified version, give it a different name and icon (see [TRADEMARKS](TRADEMARKS.md)), as permitted by GPL section 7.

## 7. Independence from Logitech and other trademark owners

Optune is an independent project. It is not affiliated with, endorsed by, or sponsored by Logitech, Apple or any other company named in it. Product names are used only to say which products Optune works with. See [TRADEMARKS](TRADEMARKS.md).

## 8. Interoperability and third-party material

Optune exists so that people can use hardware they own on macOS. It speaks the HID++ protocol, whose behaviour is documented publicly by community projects (see [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)). Optune is intended to contain **no** proprietary code, firmware, software or artwork from any device manufacturer. If you believe it does, please tell us (section 11) and we will look at it promptly.

## 9. Contributions

By submitting a contribution you confirm that you have the right to do so and that it may be distributed under the project's licence (GPL-3.0-or-later). See [CONTRIBUTING](CONTRIBUTING.md).

## 10. Website, links and availability

The Website and documentation are provided as-is and may be wrong or out of date. We link to third-party sites we don't control and aren't responsible for them. Optune and the Website may change or disappear at any time.

## 11. Copyright and other complaints

If you believe material in this repository or on the Website infringes your copyright or other rights, open an issue at <https://github.com/Sanjays2402/optune/issues> (or a [private advisory](https://github.com/Sanjays2402/optune/security/advisories/new) if the details are sensitive) with:

1. what the work is and where you published it,
2. where the allegedly infringing material is (file path or URL),
3. your contact details,
4. a statement that you have a good-faith belief the use is not authorised, and
5. a statement that the information is accurate and that you are the rights owner or authorised to act for them.

We will review complaints promptly and remove or fix material where appropriate. You can also notify GitHub through its [DMCA process](https://docs.github.com/site-policy/content-removal-policies/dmca-takedown-policy).

## 12. Changes

We may update these terms; the current version lives in the repository with its effective date, and material changes are noted in the [changelog](CHANGELOG.md). Continuing to use Optune after a change means you accept the updated terms.

## 13. General

If any part of these terms is unenforceable, the rest stays in effect. Failure to enforce a term is not a waiver. These terms, together with the GPL, are the whole agreement about your use of Optune.

## 14. Contact

Open an issue at <https://github.com/Sanjays2402/optune/issues>.
