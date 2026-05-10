import SwiftUI
import AppKit
import OptuneCore
import OptuneUI

/// First-launch welcome flow — three pages: hello, permissions, ready.
/// Sets `welcomeCompleted = true` on finish so it never reappears.
struct WelcomeWindow: View {
    @EnvironmentObject private var model: DeviceModel
    @ObservedObject private var accessibility = AccessibilityChecker.shared
    @State private var page: Int = 0
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Glassy background — same vibe as the rest of the app.
            PageBackground()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Group {
                    switch page {
                    case 0: hello
                    case 1: permissions
                    default: ready
                    }
                }
                .frame(maxWidth: 440)
                Spacer()
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(width: 560, height: 480)
    }

    private var hello: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 86, height: 86)
            .shadow(color: .accentColor.opacity(0.4), radius: 14, y: 4)

            Text("Welcome to Optune")
                .font(OptuneDesign.Typography.title)
            Text("A native macOS configurator for Logitech mice and keyboards. Unifying Bolt, Bluetooth, and USB into a single, lightweight menu-bar app.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.18))
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Two permissions to grant").font(.system(size: 15, weight: .semibold))
                    Text("Required for full functionality. Without them, button remap silently no-ops.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            InsetGroup {
                InsetRow(
                    title: "Input Monitoring",
                    subtitle: "Talk to your mice/keyboards over HID++ — battery, DPI, gestures."
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                        Image(systemName: "keyboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    .frame(width: 22, height: 22)
                } trailing: {
                    Button("Open") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                GroupDivider()

                InsetRow(
                    title: "Accessibility",
                    subtitle: "Synthesize keystrokes / gestures for custom button remaps. macOS silently drops events without it."
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accessibility.isTrusted ? Color.green.opacity(0.14) : Color.orange.opacity(0.14))
                        Image(systemName: accessibility.isTrusted ? "checkmark" : "hand.tap.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accessibility.isTrusted ? .green : .orange)
                    }
                    .frame(width: 22, height: 22)
                } trailing: {
                    if accessibility.isTrusted {
                        Text("Granted")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant") { accessibility.requestPrompt() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }

            Text("Tip: if button remap stops working after an update, remove **Optune** from System Settings → Privacy & Security → Accessibility and add it back. macOS invalidates Accessibility grants on every code-signature change.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ready: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.green.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(width: 72, height: 72)
            Text("You're all set")
                .font(OptuneDesign.Typography.title)
            Text("Optune lives in your menu bar. Click the mouse icon to peek battery and active settings; open Preferences for the full sidebar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                bullet("Per-app profiles flip DPI/SmartShift when you switch apps.")
                bullet("Custom button maps land natively on Mac for the first time.")
                bullet("Battery + connection alerts via standard macOS notifications.")
            }
            .padding(.top, 4)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.top, 2)
            Text(text).font(.system(size: 12))
        }
    }

    private var footer: some View {
        HStack {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if page > 0 {
                Button("Back") { page -= 1 }
                    .buttonStyle(.bordered)
            }
            if page < 2 {
                Button("Continue") { page += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get started") { finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func finish() {
        SettingsStore.shared.updateApp { $0.welcomeCompleted = true }
        onClose()
    }
}

/// Manages the welcome window's lifecycle. AppKit so we can present a real
/// floating window outside `Settings { … }` (which only opens via Cmd+,).
@MainActor
final class WelcomePresenter: ObservableObject {
    static let shared = WelcomePresenter()

    private var window: NSWindow?

    /// Show the welcome flow if the user hasn't seen it yet.
    func showIfNeeded(model: DeviceModel) {
        guard SettingsStore.shared.app.welcomeCompleted == false else { return }
        present(model: model)
    }

    /// Force-show, ignoring the completed flag (e.g. from a "Show welcome…" menu).
    func present(model: DeviceModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = WelcomeWindow(onClose: { [weak self] in self?.close() })
            .environmentObject(model)
        let host = NSHostingController(rootView: content)
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to Optune"
        win.styleMask = [.titled, .closable]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.center()
        win.delegate = WelcomeWindowDelegate.shared
        WelcomeWindowDelegate.shared.onClose = { [weak self] in self?.close() }
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }
}

/// Lives outside of `WelcomePresenter` because window delegates can't be
/// `@MainActor`-isolated in a way that satisfies AppKit.
@MainActor
final class WelcomeWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowDelegate()
    var onClose: (() -> Void)?
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.onClose?()
        }
    }
}
