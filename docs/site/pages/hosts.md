---
title: Hosts & Easy-Switch
section: Features
order: 140
description: HostsInfo (0x1815) reads the current host slot and lets you switch between paired Macs / PCs from the menu bar.
lede: MX Master 3S, MX Keys, and MX Anywhere can pair with up to three hosts and switch with a button. Optune surfaces the slot list and lets you switch from software too.
---

# Hosts & Easy-Switch

## HostsInfo (`0x1815`)

Modern Logitech devices speak **HostsInfo** to report which host slot they're connected to and let you switch slots over HID++.

The feature exposes:

| Function | Returns |
|---|---|
| `GetHostInfo` | Number of slots, current slot, slot capabilities. |
| `GetHostFriendlyName(slot)` | UTF-8 name the device stored when paired (e.g. "Sanjay-mini"). |
| `SetCurrentHost(slot)` | Switch to a paired slot. The device disconnects from the current host and reconnects to the chosen one. |

## What you see in Optune

Settings → **Hosts** lists every slot. Each row shows:

- Slot index (1, 2, 3)
- Friendly name from the device's flash
- Capability flags (USB / BLE / RF receiver)
- A radio button — picking a row fires `SetCurrentHost`

The current slot is highlighted with the macOS accent color.

## What happens when you switch

1. Optune sends `SetCurrentHost(2)`.
2. The device acks within ~30 ms.
3. The device disconnects from your Mac. The HID interface vanishes from IOKit.
4. Optune's `IOHIDManager` matching callback fires with `removed`. The Settings pane greys out.
5. The device reconnects to host #2.

If host #2 is *also* this Mac (e.g. you have one pairing over BLE and another over the Bolt receiver), Optune will pick the device back up within a few hundred milliseconds and the pane comes back to life.

## Quirks

- The **MX Master 3S** advertises 3 host slots even when only 1 is paired. Empty slots return an empty friendly name; Optune labels them **Empty slot**.
- Some firmwares return the friendly name padded with `0xFF` to fill the buffer. Optune trims any trailing `0xFF` byte sequence before decoding.
- Switching to a slot the device can't reach (host powered off) leaves the device in a "searching" state. Pressing the physical Easy-Switch button on the device cancels the search.

## CLI

```bash
optune hosts                       # list slots
optune hosts --switch 2            # switch to slot 2
optune hosts --device "MX Keys S"  # specify which keyboard if you have multiple
```
