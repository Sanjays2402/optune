import AppKit
import SwiftUI
import OptuneCore
import OptuneUI

/// "Finish setup" card shown at the top of the menu bar dropdown while a required
/// permission is missing. Disappears on its own once everything is granted.
struct SetupChecklist: View {
    @EnvironmentObject private var model: DeviceModel
    @ObservedObject private var accessibility = AccessibilityChecker.shared

    private var inputMissing: Bool { model.permissionMissing }
    private var accessibilityNeeded: Bool {
        !accessibility.isTrusted && (!model.remapBindings.isEmpty || !model.gestureActions.isEmpty)
    }

    var body: some View {
        if inputMissing || accessibilityNeeded {
            VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.orange)
                    Text("Finish setup").font(OptuneDesign.Typography.header)
                    Spacer()
                }
                step(
                    title: "Input Monitoring",
                    detail: "Lets Optune talk to your mouse.",
                    done: !inputMissing,
                    button: "Open Settings"
                ) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                if accessibilityNeeded || accessibility.isTrusted == false {
                    step(
                        title: "Accessibility",
                        detail: "Needed for button remaps and gestures.",
                        done: accessibility.isTrusted,
                        button: "Grant"
                    ) { accessibility.requestPrompt() }
                }
                HStack {
                    Button("Re-check") {
                        accessibility.refresh()
                        model.refresh()
                        model.refreshTelemetryNow()
                    }
                    .buttonStyle(.ghost)
                    Button("Setup guide") { WelcomePresenter.shared.present(model: model) }
                        .buttonStyle(.ghost(tint: .secondary))
                    Spacer()
                }
            }
            .glassCard(tint: .orange)
        }
    }

    private func step(title: String, detail: String, done: Bool, button: String,
                      action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(OptuneDesign.Typography.body)
                Text(detail).font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !done {
                Button(button, action: action).buttonStyle(.ghost(tint: .orange))
            }
        }
    }
}
