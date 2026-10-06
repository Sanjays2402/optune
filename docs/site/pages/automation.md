---
title: Automation
section: Features
order: 190
description: Control Optune from hotkeys, Shortcuts, scripts and the command line.
lede: Easy-Switch hotkeys, an opt-in optune:// URL scheme for Shortcuts and scripts, and automatic settings backup.
---

# Automation

## Easy-Switch hotkeys

Turn on **Settings → General → Automation → Easy-Switch hotkeys** and press:

| Keys | Action |
|---|---|
| ⌃⌥1 | Move the mouse to host 1 |
| ⌃⌥2 | Move the mouse to host 2 |
| ⌃⌥3 | Move the mouse to host 3 |

The DPI hotkey (⌃⌥D, cycles through your saved DPI stages) lives under **Pointer**. These shortcuts use the system hotkey API, so they need no extra permission.

## optune:// links

Switch on **Allow optune:// links** (off by default) and Optune accepts these URLs:

| URL | Does |
|---|---|
| `optune://dpi/1600` | Set DPI (100–32000, clamped to the device) |
| `optune://dpi/next` | Next saved DPI stage |
| `optune://host/2` | Switch to Easy-Switch host 1–3 |
| `optune://smartshift/on` | SmartShift on, off or toggle |
| `optune://scroll/freespin` | Wheel mode: ratchet, freespin or toggle |
| `optune://rate/1000` | Polling rate in Hz (devices that support it) |

From a terminal: `open "optune://dpi/800"`. In **Shortcuts**, add an **Open URLs** action with one of the links above, or a **Run Shell Script** action calling the `optune` CLI.

Links are off by default because any web page can open a custom URL; with the switch on, a page could change your DPI or host. Only enable it if you use it. Optune never runs shell commands from a URL.

## Command line

The `optune` tool does everything the links do and can read values back, for example `optune battery --json`, `optune dpi 1600`, `optune host switch 1` (CLI slots start at 0, so this is the second host) and `optune rate 1000`. See [CLI](cli.html).

## Settings backup

**Settings → General → Backup** keeps `optune-settings.json` up to date in a folder you choose — iCloud Drive, a Git repository, anywhere. The file has sorted keys, no timestamps and no battery history, so it diffs cleanly. It contains device serial numbers and any shell-command remaps. **Restore…** imports it again; if the file binds shell commands to buttons, Optune lists them and asks first.
