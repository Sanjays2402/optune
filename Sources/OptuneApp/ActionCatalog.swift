// ActionCatalog.swift
// Curated catalog of named macOS actions, inspired by Mouser's `ACTIONS` table
// in core/key_simulator.py. Mouser ships ~40 categorized presets (Navigation,
// Browser, Editing, Media, Scroll, Mouse) so a non-technical user can pick
// "Show Desktop" instead of remembering the F11 keyCode. Optune used to expose
// only 5 hardcoded keystroke presets in `ButtonRow.remapMenu`; this catalog
// replaces that ad-hoc list with a structured, searchable, future-proof set.
//
// The catalog is intentionally a flat array, not a switch on enum cases —
// `RemapAction` stays the storage format (Codable, used by `SettingsStore`),
// and the catalog only describes UI presets. Custom keystrokes captured by the
// user are still stored as `RemapAction.keystroke(...)` and just won't have a
// catalog entry; `displayName` falls back to the raw "⌘ + 0xNN" form for those.
//
// macOS virtual key codes come from Carbon's `Events.h` and are the same
// constants Quartz takes in `CGEvent(keyboardEventSource:virtualKey:keyDown:)`.

import Foundation
import CoreGraphics

public struct ActionCatalogEntry: Identifiable, Hashable, Sendable {
    public enum Category: String, CaseIterable, Sendable {
        case system        = "System"
        case navigation    = "Navigation"
        case browser       = "Browser"
        case editing       = "Editing"
        case media         = "Media"
        case mouseModes    = "Mouse Modes"
        case mouseButtons  = "Mouse Buttons"
        case app           = "Apps"
    }

    public let id: String
    public let label: String
    public let category: Category
    public let action: RemapAction
    /// SF Symbol used in the menu. Picked to match macOS conventions
    /// (e.g. `arrow.left.arrow.right` for App Switcher, `play.fill` for Play).
    public let symbol: String

    public init(id: String, label: String, category: Category, action: RemapAction, symbol: String) {
        self.id = id
        self.label = label
        self.category = category
        self.action = action
        self.symbol = symbol
    }
}

public final class ActionCatalog: @unchecked Sendable {
    public static let shared = ActionCatalog()

    /// Keystroke helper — keeps the modifier raw-value plumbing local to
    /// the catalog so individual entries stay one-line readable.
    private static func k(_ keyCode: Int, _ flags: CGEventFlags = []) -> RemapAction {
        .keystroke(keyCode: keyCode, modifiers: flags.rawValue)
    }

    public let entries: [ActionCatalogEntry]

    private init() {
        // macOS virtual keycodes (subset). Constants pulled from
        // <HIToolbox/Events.h>. The `kVK_` prefix is dropped for brevity.
        let ANSI_A = 0
        let ANSI_C = 8
        let ANSI_V = 9
        let ANSI_X = 7
        let ANSI_Z = 6
        let ANSI_S = 1
        let ANSI_F = 3
        let ANSI_T = 17
        let ANSI_W = 13
        let ANSI_N = 45
        let ANSI_R = 15
        let TAB = 48
        let LEFT = 123
        let RIGHT = 124
        let HOME = 115
        let END = 119
        let PAGE_UP = 116
        let PAGE_DOWN = 121
        let SPACE = 49

        let cmd: CGEventFlags = .maskCommand
        let shift: CGEventFlags = .maskShift
        let ctrl: CGEventFlags = .maskControl

        var rows: [ActionCatalogEntry] = []

        // System / Mission Control — Mouser exposes these via `mission_control`,
        // `app_expose`, `show_desktop`, `launchpad`. Optune already had them as
        // `systemSwipe(slot:)`; we just give them named catalog entries here.
        rows += [
            .init(id: "sys.mission",     label: "Mission Control",      category: .system, action: .systemSwipe(slot: 0), symbol: "rectangle.3.group"),
            .init(id: "sys.appexpose",   label: "Application Windows",  category: .system, action: .systemSwipe(slot: 1), symbol: "macwindow.on.rectangle"),
            .init(id: "sys.desktop",     label: "Show Desktop",         category: .system, action: .systemSwipe(slot: 2), symbol: "desktopcomputer"),
            .init(id: "sys.launchpad",   label: "Launchpad",            category: .system, action: .systemSwipe(slot: 3), symbol: "square.grid.3x3.fill"),
            // Spotlight and Notification Centre are first-class macOS things
            // Mouser doesn't have a direct preset for; bonus over Mouser.
            .init(id: "sys.spotlight",   label: "Spotlight Search",     category: .system, action: Self.k(SPACE, cmd), symbol: "magnifyingglass"),
        ]

        // Navigation — Mouser's `alt_tab`, `alt_shift_tab`, page nav, space switch.
        // On macOS, app-switcher is ⌘Tab; "previous/next desktop" are ⌃← / ⌃→.
        rows += [
            .init(id: "nav.appswitch",   label: "Switch Apps (⌘Tab)",        category: .navigation, action: Self.k(TAB, cmd),                 symbol: "arrow.left.arrow.right"),
            .init(id: "nav.appswback",   label: "Switch Apps Back (⌘⇧Tab)",  category: .navigation, action: Self.k(TAB, [cmd, shift]),        symbol: "arrow.uturn.backward"),
            .init(id: "nav.spaceleft",   label: "Previous Desktop (⌃←)",     category: .navigation, action: Self.k(LEFT, ctrl),                symbol: "chevron.left.square"),
            .init(id: "nav.spaceright",  label: "Next Desktop (⌃→)",         category: .navigation, action: Self.k(RIGHT, ctrl),               symbol: "chevron.right.square"),
            .init(id: "nav.pageup",      label: "Page Up",                   category: .navigation, action: Self.k(PAGE_UP),                   symbol: "arrow.up.to.line"),
            .init(id: "nav.pagedown",    label: "Page Down",                 category: .navigation, action: Self.k(PAGE_DOWN),                 symbol: "arrow.down.to.line"),
            .init(id: "nav.home",        label: "Home",                      category: .navigation, action: Self.k(HOME),                      symbol: "arrow.up.left"),
            .init(id: "nav.end",         label: "End",                       category: .navigation, action: Self.k(END),                       symbol: "arrow.down.right"),
        ]

        // Browser — Mouser's `browser_back`, `browser_forward`, tab management.
        // macOS uses ⌘[ / ⌘] for back/forward in Safari/Chrome rather than Alt+Arrow.
        rows += [
            .init(id: "br.back",     label: "Browser Back (⌘[)",          category: .browser, action: Self.k(33, cmd),                  symbol: "chevron.backward"),
            .init(id: "br.forward",  label: "Browser Forward (⌘])",       category: .browser, action: Self.k(30, cmd),                  symbol: "chevron.forward"),
            .init(id: "br.newtab",   label: "New Tab (⌘T)",                category: .browser, action: Self.k(ANSI_T, cmd),              symbol: "plus.rectangle"),
            .init(id: "br.closetab", label: "Close Tab (⌘W)",              category: .browser, action: Self.k(ANSI_W, cmd),              symbol: "xmark.rectangle"),
            .init(id: "br.nexttab",  label: "Next Tab (⌃Tab)",             category: .browser, action: Self.k(TAB, ctrl),                symbol: "arrow.right"),
            .init(id: "br.prevtab",  label: "Previous Tab (⌃⇧Tab)",        category: .browser, action: Self.k(TAB, [ctrl, shift]),       symbol: "arrow.left"),
            .init(id: "br.reopen",   label: "Reopen Closed Tab (⌘⇧T)",     category: .browser, action: Self.k(ANSI_T, [cmd, shift]),     symbol: "arrow.uturn.left.circle"),
            .init(id: "br.refresh",  label: "Refresh (⌘R)",                category: .browser, action: Self.k(ANSI_R, cmd),              symbol: "arrow.clockwise"),
        ]

        // Editing — Mouser's copy/paste/cut/undo/select-all/save/find. All bind
        // to ⌘ rather than ⌃ since this is a macOS-native catalog.
        rows += [
            .init(id: "ed.copy",   label: "Copy (⌘C)",       category: .editing, action: Self.k(ANSI_C, cmd),          symbol: "doc.on.doc"),
            .init(id: "ed.paste",  label: "Paste (⌘V)",      category: .editing, action: Self.k(ANSI_V, cmd),          symbol: "doc.on.clipboard"),
            .init(id: "ed.cut",    label: "Cut (⌘X)",        category: .editing, action: Self.k(ANSI_X, cmd),          symbol: "scissors"),
            .init(id: "ed.undo",   label: "Undo (⌘Z)",       category: .editing, action: Self.k(ANSI_Z, cmd),          symbol: "arrow.uturn.backward"),
            .init(id: "ed.redo",   label: "Redo (⌘⇧Z)",     category: .editing, action: Self.k(ANSI_Z, [cmd, shift]), symbol: "arrow.uturn.forward"),
            .init(id: "ed.selectAll", label: "Select All (⌘A)", category: .editing, action: Self.k(ANSI_A, cmd),       symbol: "selection.pin.in.out"),
            .init(id: "ed.save",   label: "Save (⌘S)",       category: .editing, action: Self.k(ANSI_S, cmd),          symbol: "tray.and.arrow.down"),
            .init(id: "ed.find",   label: "Find (⌘F)",       category: .editing, action: Self.k(ANSI_F, cmd),          symbol: "magnifyingglass"),
            .init(id: "ed.newDoc", label: "New Document (⌘N)", category: .editing, action: Self.k(ANSI_N, cmd),         symbol: "doc.badge.plus"),
        ]

        // Media — Mouser's volume/play/skip. Use proper NSSystemDefined codes
        // through `RemapAction.mediaKey` rather than F-key keystrokes — the
        // F-key approach only works if the user has "Use F1, F2, etc. as
        // standard function keys" disabled, which we can't guarantee.
        rows += [
            .init(id: "md.playpause", label: "Play / Pause",     category: .media, action: .mediaKey(key: 0), symbol: "playpause.fill"),
            .init(id: "md.next",      label: "Next Track",       category: .media, action: .mediaKey(key: 1), symbol: "forward.fill"),
            .init(id: "md.prev",      label: "Previous Track",   category: .media, action: .mediaKey(key: 2), symbol: "backward.fill"),
            .init(id: "md.volup",     label: "Volume Up",        category: .media, action: .mediaKey(key: 3), symbol: "speaker.wave.3.fill"),
            .init(id: "md.voldown",   label: "Volume Down",      category: .media, action: .mediaKey(key: 4), symbol: "speaker.wave.1.fill"),
            .init(id: "md.mute",      label: "Mute",             category: .media, action: .mediaKey(key: 5), symbol: "speaker.slash.fill"),
            .init(id: "md.brightup",  label: "Brightness Up",    category: .media, action: .mediaKey(key: 6), symbol: "sun.max.fill"),
            .init(id: "md.brightdn",  label: "Brightness Down",  category: .media, action: .mediaKey(key: 7), symbol: "sun.min.fill"),
        ]

        // Mouse Modes — Mouser's `cycle_dpi`, `toggle_smart_shift`, `switch_scroll_mode`.
        // These tap the live `DeviceModel` via `RemapActionDispatcher`.
        rows += [
            .init(id: "mode.cycleDPI",       label: "Cycle DPI Presets",         category: .mouseModes, action: .cycleDPI,         symbol: "speedometer"),
            .init(id: "mode.toggleSmart",    label: "Toggle SmartShift",         category: .mouseModes, action: .toggleSmartShift, symbol: "wand.and.stars"),
            .init(id: "mode.toggleScroll",   label: "Switch Scroll Mode",        category: .mouseModes, action: .toggleScrollMode, symbol: "arrow.up.and.down.righttriangle.up.fill.righttriangle.down.fill"),
        ]

        // Mouse Buttons — Mouser's `mouse_*_click` series.
        // Lets the user remap the gesture button to act as middle / back / forward.
        rows += [
            .init(id: "mb.left",     label: "Left Click",          category: .mouseButtons, action: .mouseClick(button: 0), symbol: "cursorarrow.click"),
            .init(id: "mb.right",    label: "Right Click",         category: .mouseButtons, action: .mouseClick(button: 1), symbol: "cursorarrow.click.2"),
            .init(id: "mb.middle",   label: "Middle Click",        category: .mouseButtons, action: .mouseClick(button: 2), symbol: "circle.dashed"),
            .init(id: "mb.back",     label: "Back (Mouse 4)",      category: .mouseButtons, action: .mouseClick(button: 3), symbol: "arrow.left.circle"),
            .init(id: "mb.forward",  label: "Forward (Mouse 5)",   category: .mouseButtons, action: .mouseClick(button: 4), symbol: "arrow.right.circle"),
        ]

        // Apps — keep the v0.6 trio for now; the user-extensible app picker
        // is a separate UI surface (out of scope for this PR).
        rows += [
            .init(id: "app.safari",   label: "Safari",   category: .app, action: .openApp(bundleID: "com.apple.Safari"),   symbol: "safari"),
            .init(id: "app.terminal", label: "Terminal", category: .app, action: .openApp(bundleID: "com.apple.Terminal"), symbol: "terminal"),
            .init(id: "app.notes",    label: "Notes",    category: .app, action: .openApp(bundleID: "com.apple.Notes"),    symbol: "note.text"),
        ]

        self.entries = rows
    }

    /// Reverse lookup — given a stored `keystroke` action, find its catalog
    /// entry so `RemapAction.displayName` shows "Copy (⌘C)" rather than
    /// "⌘ + 0x08". Returns nil for keystrokes the user authored manually.
    public func lookup(keyCode: Int, modifiers: UInt64) -> ActionCatalogEntry? {
        entries.first { entry in
            if case let .keystroke(kc, mods) = entry.action {
                return kc == keyCode && mods == modifiers
            }
            return false
        }
    }

    /// Catalog entries grouped by category, preserving insertion order.
    /// Used by the menu UI so categories land in a predictable order.
    public var groupedByCategory: [(ActionCatalogEntry.Category, [ActionCatalogEntry])] {
        ActionCatalogEntry.Category.allCases.compactMap { cat in
            let items = entries.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
