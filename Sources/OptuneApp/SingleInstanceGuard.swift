// SingleInstanceGuard.swift
// Detect a second copy of Optune launching and politely tell the existing
// instance to focus its menu bar / settings window instead of letting two
// menu-bar icons pile up. Inspired by Mouser's `_try_activate_existing_instance`
// pattern, adapted to macOS using NSDistributedNotificationCenter — no UNIX
// socket plumbing needed since macOS already has a system-wide notification bus.
//
// Why this matters on macOS specifically:
// 1. SwiftUI's `MenuBarExtra` happily registers a second status item if you
//    launch the bundle twice (e.g. via `open -n /Applications/Optune.app` or
//    a stale LaunchAgent). The user sees two copies of the icon, both fighting
//    over the same HID++ transport — and the transport open contention can
//    cause sporadic disconnections.
// 2. Logitech Options+ has the same bug and Logi solves it by checksumming the
//    bundle path; we just use a private notification channel.
//
// The first instance becomes the "owner": it observes the notification.
// Any subsequent instance sends `optune.activate` and immediately exits.
// The owner reacts by activating itself + re-presenting the settings window.

import Foundation
import AppKit
import SwiftUI

@MainActor
public enum SingleInstanceGuard {
    /// Notification name used between Optune processes. Namespaced under the
    /// bundle ID so it doesn't collide with anything else on the user's box.
    private static let notificationName = Notification.Name("io.github.sanjays2402.optune.activate")

    /// Returns `true` if this process should keep running (it's the owner).
    /// Returns `false` if another instance already exists — in that case we
    /// post the activate notification and the caller should `exit(0)`.
    public static func acquireOrTrigger() -> Bool {
        // NSRunningApplication enumerates all processes by bundle ID. If we
        // see more than just ourselves, we're a duplicate.
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.sanjays2402.optune"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let others = running.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if others.isEmpty {
            // First copy. Become the owner — listen for future activate pings.
            installOwnerObserver()
            return true
        } else {
            // Already running — ping the owner to focus, then quit ourselves.
            DistributedNotificationCenter.default().post(name: notificationName, object: nil)
            // Best-effort: also call activate(options:) on the existing app
            // so its menu bar icon flashes — handles the case where the
            // notification observer hasn't installed yet (race during boot).
            others.first?.activate(options: [.activateAllWindows])
            return false
        }
    }

    /// Install a one-shot observer in the owner process. When a duplicate
    /// posts `optune.activate`, we activate ourselves and bring up Settings.
    /// `NSApp` and `sendAction` are MainActor-isolated under Swift 6 strict
    /// concurrency — the closure body must hop there explicitly even though
    /// `queue: .main` already pins the dispatch.
    private static func installOwnerObserver() {
        DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                // Open the Settings window if it isn't already up. SwiftUI's
                // `Settings { }` scene answers to the standard ⌘, command.
                // We invoke it via the responder chain instead of a private API.
                let showSettings = Selector(("showSettingsWindow:"))
                if NSApp.responds(to: showSettings) {
                    NSApp.sendAction(showSettings, to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("orderFrontStandardAboutPanel:")), to: nil, from: nil)
                }
            }
        }
    }
}
