import AppKit
import ApplicationServices
import Combine
import Foundation

/// Live observer of the macOS Accessibility (TCC) trust state.
///
/// **Why this exists**: `CGEvent.post` is the only API available to a non-signed
/// menu-bar agent for synthesizing keystrokes / mouse events. macOS silently
/// drops every event a process tries to post unless that process has been
/// explicitly granted Accessibility under System Settings → Privacy & Security
/// → Accessibility. There's no error, no return code, no log — events just
/// vanish into the void. So the only way to surface "your remap isn't working"
/// is to poll `AXIsProcessTrusted()` ourselves and gate the UI on it.
///
/// **The TCC reset trap**: Apple's permission database keys grants on
/// `(bundleID, binary signature, binary path)`. The moment we ship a new
/// release the binary hash changes, the prior grant is invalidated, but the
/// row stays in the Accessibility list with the toggle visually *on*. The user
/// flips it off and back on — fine — but if they don't, the app appears
/// permitted and silently broken. We detect that case here and show a
/// "Re-grant required" banner.
///
/// Owns a 2 s timer that keeps `isTrusted` in sync without blocking the main
/// actor. UI binds to `@Published` properties.
@MainActor
final class AccessibilityChecker: ObservableObject {
    static let shared = AccessibilityChecker()

    /// Whether the OS currently trusts this process to post synthetic events.
    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    /// Number of times the user has consciously dismissed the permission
    /// nudge. Used to suppress repeat banners — once is enough until the next
    /// time they actually try to fire a remap.
    @Published var bannerDismissed: Bool = false

    private var timer: Timer?

    private init() {
        startPolling()
    }

    /// Begin a 2-second poll. Cheap — `AXIsProcessTrusted()` is a single
    /// XPC round trip. Stops as soon as we go from `false → true` to avoid
    /// burning a wakeup forever once permission is granted.
    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.isTrusted {
                    self.isTrusted = trusted
                    if trusted {
                        // Stop polling once granted — we'll resume only if the
                        // user revokes (the next refresh from any UI surface).
                        self.timer?.invalidate()
                        self.timer = nil
                    }
                }
            }
        }
    }

    /// Force an immediate re-check. Cheap, safe to call from any UI surface.
    func refresh() {
        isTrusted = AXIsProcessTrusted()
        if !isTrusted && timer == nil {
            startPolling()
        }
    }

    /// Trigger the system Accessibility prompt. macOS only shows the prompt
    /// once per process lifetime — subsequent calls are no-ops. After the
    /// user clicks "Open System Settings" in the prompt we open the pane
    /// ourselves as a fallback.
    func requestPrompt() {
        // Use the literal key string instead of `kAXTrustedCheckOptionPrompt`
        // — Swift 6 strict concurrency flags the global as non-Sendable, but
        // the value is documented and stable: kAXTrustedCheckOptionPrompt =
        // "AXTrustedCheckOptionPrompt".
        let opts: NSDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true]
        _ = AXIsProcessTrustedWithOptions(opts)
        // Fire-and-forget: regardless of whether the prompt sheet appears
        // (it doesn't on subsequent calls), open the pane in 600 ms so the
        // user always lands somewhere actionable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.openSettingsPane()
        }
    }

    /// Open the Accessibility list in System Settings. Works on macOS 13+
    /// via the `x-apple.systempreferences:` URL scheme.
    func openSettingsPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// **TCC reset helper** — surface the "I granted it but it still doesn't
    /// work" case. The fix is to remove and re-add Optune from the
    /// Accessibility list (rebuilds the signature key). We can't do that from
    /// in-process, but we can deep-link the user there and tell them what
    /// to click.
    var resetGuidanceText: String {
        "If Optune is already listed in Accessibility but remap still doesn't fire, remove it (–) and add it back (+). macOS invalidates the grant whenever the app is updated."
    }
}
