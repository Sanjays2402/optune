---
title: HID++ primer
section: Reference
order: 250
description: A short, practical introduction to the HID++ 2.0 protocol — what a feature is, how reports are framed, where the gotchas live.
lede: Everything Optune does sits on top of HID++ 2.0. If you want to add a feature or debug a quirk, this is the 5-minute mental model.
---

# HID++ primer

## What HID++ is

**HID++** is Logitech's proprietary protocol layered on top of standard USB HID. Every Logitech device speaks two HID interfaces:

- A normal one — keyboard reports, mouse reports, the stuff macOS reads natively
- A second one carrying HID++ frames

The second interface uses **report ID 0x10** (short, 7 bytes) and **report ID 0x11** (long, 20 bytes). Optune only ever sends and receives `0x11`.

Within HID++ there are two protocol versions in the wild:

- **HID++ 1.0** — used by older devices (MX Anywhere 2 era). Optune doesn't support it.
- **HID++ 2.0** — the current one. Everything in [`devices.json`](adding-a-device.html) is 2.0.

Detecting the version is one frame: send `getProtocolVersion`, the response tells you.

## Features, not commands

HID++ 2.0 organises capabilities as **features**. A feature has:

- A 16-bit **feature ID** (e.g. `0x1004` for UnifiedBattery, `0x2201` for AdjustableDPI)
- A 4-bit **feature index** assigned by the firmware on a per-device basis
- One or more **functions** (e.g. `getStatus`, `setSensorDpi`)
- An optional set of **events** (firmware-pushed messages)

The feature index is **not** stable across devices — even two of the same model can assign UnifiedBattery different indices. Always enumerate the feature set on first connection and cache the map.

## Frame layout

```
byte 0   report ID                  0x11 (long)
byte 1   device index               0xFF for receiver, slot otherwise
byte 2   feature index              from the cached map
byte 3   function index | swid      function<<4 | software_id
byte 4..19  parameters (16 bytes)   function-specific
```

When the firmware responds, it echoes bytes 0–3 (so you can match on `swid`) and writes its payload into bytes 4–19.

## The error frame

If the firmware can't honour your request, it sends:

```
byte 0   0x11
byte 1   device index
byte 2   0x8F                       error feature
byte 3   echoed function | swid
byte 4   error code                 INVALID_FUNCTION_ID, INVALID_ARGUMENT, etc.
byte 5..19  zeros
```

`HIDPPTransport` catches `0x8F` automatically and surfaces it as `HIDPPError.protocolError(.invalidArgument)` in Swift.

## Notifications

Some features push events without a preceding request — battery low, button divert, host change. The frame layout is identical to a response except `swid = 0`. Optune dispatches notifications via a per-feature subscription closure registered with `HIDPPTransport`.

## Capabilities, capabilities, capabilities

Two devices of the same model can have different capability flags depending on firmware. Don't assume — call `getCapabilities` on every feature that exposes one and gate the UI on the response.

This is why Optune greys out instead of hiding. If a feature is supported but the capability flag says "not on this firmware revision", the row stays visible with a tooltip; if the firmware doesn't expose the feature at all, the row is hidden entirely.

## Going deeper

The closest thing to public documentation is the **Solaar** wiki and the **logiops** project on Linux. Their feature decoders are GPL'd — Optune doesn't share code with either, but if you want to add a feature Optune doesn't have yet, those repos are the reference.
