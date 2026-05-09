import SwiftUI
import OptuneCore
import OptuneUI

/// Menu bar dropdown — Liquid Glass surface, live telemetry, refined typography.
struct MenuContent: View {
    @EnvironmentObject private var model: DeviceModel
    @Environment(\.openSettings) private var openSettings
    @State private var hoveredAction: MenuAction?

    var body: some View {
        VStack(spacing: 0) {
            HeaderCard()
                .padding(.horizontal, OptuneDesign.Spacing.lg)
                .padding(.top, OptuneDesign.Spacing.lg)
                .padding(.bottom, OptuneDesign.Spacing.md)

            if let device = model.primaryDevice, let descriptor = model.primaryDescriptor {
                DeviceCard(device: device, descriptor: descriptor, telemetry: model.telemetry)
                    .padding(.horizontal, OptuneDesign.Spacing.lg)
                    .padding(.bottom, OptuneDesign.Spacing.md)
            } else {
                EmptyDeviceCard()
                    .padding(.horizontal, OptuneDesign.Spacing.lg)
                    .padding(.bottom, OptuneDesign.Spacing.md)
            }

            Divider().opacity(0.4).padding(.horizontal, OptuneDesign.Spacing.lg)

            VStack(spacing: 1) {
                ForEach(MenuAction.allCases) { action in
                    MenuRow(action: action, isHovered: hoveredAction == action)
                        .onHover { hoveredAction = $0 ? action : nil }
                        .onTapGesture { run(action) }
                }
            }
            .padding(.horizontal, OptuneDesign.Spacing.sm)
            .padding(.vertical, OptuneDesign.Spacing.sm)
        }
        .background(LiquidGlassSurface())
        .clipShape(RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous))
    }

    private func run(_ action: MenuAction) {
        switch action {
        case .refresh:
            model.refresh()
            model.refreshTelemetryNow()
        case .openSettings:
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        case .openProject:
            if let url = URL(string: OptuneCore.Optune.projectURL) {
                NSWorkspace.shared.open(url)
            }
        case .quit:
            NSApp.terminate(nil)
        }
    }
}

private enum MenuAction: String, CaseIterable, Identifiable {
    case refresh, openSettings, openProject, quit

    var id: String { rawValue }
    var label: String {
        switch self {
        case .refresh: return "Refresh telemetry"
        case .openSettings: return "Settings…"
        case .openProject: return "GitHub repository"
        case .quit: return "Quit Optune"
        }
    }

    var symbol: String {
        switch self {
        case .refresh: return "arrow.clockwise"
        case .openSettings: return "slider.horizontal.3"
        case .openProject: return "arrow.up.right.square"
        case .quit: return "power"
        }
    }

    var keys: [String] {
        switch self {
        case .refresh: return ["⌘", "R"]
        case .openSettings: return ["⌘", ","]
        case .openProject: return []
        case .quit: return ["⌘", "Q"]
        }
    }

    var isDestructive: Bool { self == .quit }
}

// MARK: - Header

private struct HeaderCard: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        HStack(alignment: .center, spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.linearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: Color.accentColor.opacity(0.30), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 0) {
                Text("Optune").font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("v\(OptuneCore.Optune.version) · \(model.recognizedCount) device\(model.recognizedCount == 1 ? "" : "s")")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if model.isPolling {
                ProgressView().controlSize(.small).tint(.accentColor)
            }
        }
    }
}

// MARK: - Device card (live telemetry)

private struct DeviceCard: View {
    let device: LogitechDevice
    let descriptor: DeviceDescriptor
    let telemetry: DeviceTelemetry

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack(alignment: .center, spacing: OptuneDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.tint.opacity(0.16))
                    Image(systemName: "computermouse")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(descriptor.modelName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    HStack(spacing: 5) {
                        Text(transportLabel(device))
                            .font(OptuneDesign.Typography.caption)
                            .foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(String(format: "0x%04X", device.productID))
                            .font(OptuneDesign.Typography.mono)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                ConnectionChip(connected: true)
            }

            VStack(spacing: OptuneDesign.Spacing.sm) {
                BatteryRow(state: telemetry.battery)
                DPIRow(state: telemetry.dpi, descriptor: descriptor)
                SmartShiftRow(state: telemetry.smartShift, descriptor: descriptor)
                ButtonsRow(state: telemetry.buttons, descriptor: descriptor)
            }
        }
        .glassCard()
    }

    private func transportLabel(_ d: LogitechDevice) -> String {
        guard let t = d.transport else { return "USB" }
        if t.localizedCaseInsensitiveContains("bluetooth") { return "BLE" }
        if t.localizedCaseInsensitiveContains("bolt")      { return "Bolt" }
        return t
    }
}

// MARK: - Telemetry rows

private struct BatteryRow: View {
    let state: DeviceTelemetry.Battery

    var body: some View {
        FeatureRow(
            symbol: symbol,
            symbolTint: tint,
            label: "Battery",
            secondary: secondaryLabel
        ) {
            CapabilityPill(text: pillText, tone: pillTone)
        }
    }

    private var symbol: String {
        switch state {
        case .ok(let p, let charging, _):
            if charging { return "battery.100.bolt" }
            switch p {
            case ..<10: return "battery.0"
            case ..<35: return "battery.25"
            case ..<60: return "battery.50"
            case ..<85: return "battery.75"
            default:    return "battery.100"
            }
        case .unavailable: return "exclamationmark.triangle"
        case .unknown:     return "battery.100"
        }
    }

    private var tint: Color {
        switch state {
        case .ok(let p, let charging, _):
            if charging { return .green }
            return p < 20 ? .red : .accentColor
        case .unavailable: return .orange
        case .unknown:     return .secondary
        }
    }

    private var secondaryLabel: String? {
        switch state {
        case .ok(_, let charging, let ext):
            if charging { return "Charging" }
            if ext { return "Plugged in" }
            return nil
        case .unavailable(let why): return why
        case .unknown: return "Polling…"
        }
    }

    private var pillText: String {
        switch state {
        case .ok(let p, _, _): return "\(p)%"
        case .unavailable:     return "—"
        case .unknown:         return "—"
        }
    }

    private var pillTone: CapabilityPill.Tone {
        switch state {
        case .ok(let p, let charging, _):
            if charging { return .positive }
            if p < 20 { return .danger }
            if p < 40 { return .warning }
            return .accent
        case .unavailable: return .warning
        case .unknown: return .neutral
        }
    }
}

private struct DPIRow: View {
    let state: DeviceTelemetry.DPI
    let descriptor: DeviceDescriptor

    var body: some View {
        FeatureRow(
            symbol: "scope",
            symbolTint: .accentColor,
            label: "Pointer",
            secondary: secondary
        ) {
            CapabilityPill(text: pillText, tone: pillTone)
        }
    }

    private var secondary: String? {
        switch state {
        case .ok(_, let lo, let hi, _, _):
            return "\(lo)–\(hi) dpi range"
        case .unavailable(let why): return why
        case .unknown: return "Reading…"
        }
    }

    private var pillText: String {
        switch state {
        case .ok(let cur, _, _, _, _): return "\(cur) dpi"
        case .unavailable: return "—"
        case .unknown: return "—"
        }
    }

    private var pillTone: CapabilityPill.Tone {
        switch state {
        case .ok: return .accent
        case .unavailable: return .warning
        case .unknown: return .neutral
        }
    }
}

private struct SmartShiftRow: View {
    let state: DeviceTelemetry.SmartShift
    let descriptor: DeviceDescriptor

    var body: some View {
        FeatureRow(
            symbol: "wand.and.rays",
            symbolTint: .purple,
            label: "SmartShift",
            secondary: secondary
        ) {
            CapabilityPill(text: pillText, tone: pillTone)
        }
    }

    private var secondary: String? {
        switch state {
        case .ok(_, let t, _): return "Sensitivity \(t)"
        case .unavailable(let why): return why
        case .unknown: return "Reading…"
        }
    }

    private var pillText: String {
        switch state {
        case .ok(let on, _, _): return on ? "On" : "Off"
        case .unavailable: return "—"
        case .unknown: return "—"
        }
    }

    private var pillTone: CapabilityPill.Tone {
        switch state {
        case .ok(let on, _, _): return on ? .positive : .neutral
        case .unavailable: return .warning
        case .unknown: return .neutral
        }
    }
}

private struct ButtonsRow: View {
    let state: DeviceTelemetry.Buttons
    let descriptor: DeviceDescriptor

    var body: some View {
        FeatureRow(
            symbol: "rectangle.grid.2x2",
            symbolTint: .pink,
            label: "Buttons",
            secondary: secondary
        ) {
            CapabilityPill(text: pillText, tone: pillTone)
        }
    }

    private var secondary: String? {
        switch state {
        case .ok(let cs):
            let reprog = cs.filter(\.isReprogrammable).count
            return "\(reprog) reprogrammable"
        case .unavailable(let why): return why
        case .unknown: return "Enumerating…"
        }
    }

    private var pillText: String {
        switch state {
        case .ok(let cs): return "\(cs.count)"
        case .unavailable, .unknown: return "—"
        }
    }

    private var pillTone: CapabilityPill.Tone {
        switch state {
        case .ok: return .accent
        case .unavailable: return .warning
        case .unknown: return .neutral
        }
    }
}

private struct EmptyDeviceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                Text("No supported device detected")
                    .font(OptuneDesign.Typography.header)
            }
            Text("Connect an MX Master 3S via Bluetooth or Bolt receiver. Optune will appear automatically.")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: .gray)
    }
}

// MARK: - Menu rows

private struct MenuRow: View {
    let action: MenuAction
    let isHovered: Bool

    var body: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: action.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(action.isDestructive ? .red : (isHovered ? .primary : .secondary))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 16)
            Text(action.label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(action.isDestructive ? .red : .primary)
            Spacer()
            if action.keys.count >= 2 {
                KeyHint(action.keys[0], action.keys[1])
                    .opacity(isHovered ? 1 : 0.55)
            } else if let single = action.keys.first {
                KeyHint(single)
                    .opacity(isHovered ? 1 : 0.55)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.row, style: .continuous)
                .fill(isHovered
                      ? (action.isDestructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.07))
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(OptuneDesign.Motion.glide, value: isHovered)
    }
}
