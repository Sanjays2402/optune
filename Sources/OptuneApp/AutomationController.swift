import AppKit
import Combine
import SwiftUI
import OptuneCore
import OptuneUI

/// Scriptable entry points: Easy-Switch hotkeys (⌃⌥1/2/3) and the `optune://` URL scheme
/// (usable from Shortcuts' "Open URL" action, `open`, or AppleScript). Both are opt-in.
@MainActor
final class AutomationController: ObservableObject {
    static let shared = AutomationController()

    @Published private(set) var urlEnabled: Bool
    @Published private(set) var hostHotkeysEnabled: Bool

    private weak var model: DeviceModel?
    private let store = SettingsStore.shared

    private init() {
        urlEnabled = SettingsStore.shared.app.urlSchemeEnabled
        hostHotkeysEnabled = SettingsStore.shared.app.hostHotkeysEnabled
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func attach(_ model: DeviceModel) {
        self.model = model
        syncHotkeys()
    }

    func setURLEnabled(_ enabled: Bool) {
        urlEnabled = enabled
        store.updateApp { $0.urlSchemeEnabled = enabled }
    }

    func setHostHotkeysEnabled(_ enabled: Bool) {
        hostHotkeysEnabled = enabled
        store.updateApp { $0.hostHotkeysEnabled = enabled }
        syncHotkeys()
    }

    private func syncHotkeys() {
        let keyCodes: [UInt32] = [18, 19, 20]   // kVK_ANSI_1 / 2 / 3
        for (i, key) in keyCodes.enumerated() {
            let id = UInt32(20 + i)
            if hostHotkeysEnabled {
                GlobalHotkey.shared.register(id: id, keyCode: key) {
                    Task { @MainActor in AutomationController.shared.model?.switchHost(to: UInt8(i)) }
                }
            } else {
                GlobalHotkey.shared.unregister(id: id)
            }
        }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        handle(url)
    }

    func handle(_ url: URL) {
        guard urlEnabled, let model, let command = URLCommand.parse(url) else { return }
        switch command {
        case .dpi(let value):
            model.applyDPI(value)
        case .dpiNext:
            model.cycleDPIPreset()
        case .dpiPrevious:
            model.cycleDPIPreviousPreset()
        case .host(let slot):
            model.switchHost(to: UInt8(slot - 1))
        case .smartShift(let mode):
            switch mode {
            case .on:     model.setSmartShiftEnabled(true)
            case .off:    model.setSmartShiftEnabled(false)
            case .toggle: RemapActionDispatcher.shared?.toggleSmartShift()
            }
        case .scroll(let mode):
            switch mode {
            case .ratchet:  model.setWheelRatchet(true)
            case .freespin: model.setWheelRatchet(false)
            case .toggle:   RemapActionDispatcher.shared?.toggleScrollMode()
            }
        case .reportRate(let hz):
            model.setReportRate(hz: hz)
        }
    }
}

/// General-pane section with the two opt-in automation switches.
struct AutomationSection: View {
    @ObservedObject private var automation = AutomationController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Automation")
            InsetGroup {
                InsetRow(
                    title: "Easy-Switch hotkeys",
                    subtitle: "⌃⌥1, ⌃⌥2 and ⌃⌥3 move your mouse to host 1, 2 or 3 from anywhere."
                ) {
                    tile("rectangle.connected.to.line.below", .indigo)
                } trailing: {
                    Toggle("", isOn: Binding(
                        get: { automation.hostHotkeysEnabled },
                        set: { automation.setHostHotkeysEnabled($0) }
                    ))
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
                GroupDivider()
                InsetRow(
                    title: "Allow optune:// links",
                    subtitle: "Lets Shortcuts, scripts and links control the device. Off by default — any web page can open a link."
                ) {
                    tile("link", .teal)
                } trailing: {
                    Toggle("", isOn: Binding(
                        get: { automation.urlEnabled },
                        set: { automation.setURLEnabled($0) }
                    ))
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
                if automation.urlEnabled {
                    GroupDivider()
                    Text("optune://dpi/1600 · dpi/next · host/2 · smartshift/on|off|toggle · scroll/ratchet|freespin|toggle · rate/1000")
                        .font(OptuneDesign.Typography.mono)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
                        .padding(.vertical, OptuneDesign.Spacing.md)
                }
            }
        }
    }

    private func tile(_ symbol: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
    }
}
