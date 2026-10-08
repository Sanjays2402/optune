import AppKit
import SwiftUI
import OptuneCore
import OptuneUI

/// Sheet that records a key combination and hands it back as a `RemapAction.keystroke`.
struct ShortcutRecorderSheet: View {
    let onSave: (RemapAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var captured: (code: Int, mods: UInt64)?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom shortcut").font(OptuneDesign.Typography.title2)
                Text("Press the key combination this button should send, for example ⇧⌘K.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(captured == nil ? 0.5 : 0.9), lineWidth: 1.2)
                Text(captured.map { KeyCombo.format(keyCode: $0.code, modifiers: $0.mods) } ?? "Waiting for keys…")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(captured == nil ? .secondary : .primary)
                KeyCaptureView { code, mods in captured = (code, mods) }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
            }
            .frame(height: 76)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Use shortcut") {
                    if let captured {
                        onSave(.keystroke(keyCode: captured.code, modifiers: captured.mods))
                    }
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(captured == nil)
            }
        }
        .padding(OptuneDesign.Spacing.xl)
        .frame(width: 380)
    }
}

/// Invisible view that takes keyboard focus and reports every key press, including ⌘-combos
/// (which would otherwise be swallowed by the menu bar).
private struct KeyCaptureView: NSViewRepresentable {
    let onKey: (Int, UInt64) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ view: CaptureView, context: Context) {
        view.onKey = onKey
    }

    final class CaptureView: NSView {
        var onKey: ((Int, UInt64) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) { report(event) }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            report(event)
            return true
        }

        private func report(_ event: NSEvent) {
            let mods = UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue) & KeyCombo.modifierMask
            onKey?(Int(event.keyCode), mods)
        }
    }
}
