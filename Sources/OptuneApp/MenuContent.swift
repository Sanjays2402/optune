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
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                EmptyDeviceCard()
                    .padding(.horizontal, OptuneDesign.Spacing.lg)
                    .padding(.bottom, OptuneDesign.Spacing.md)
            }

            Divider().opacity(0.4).padding(.horizontal, OptuneDesign.Spacing.lg)

            VStack(spacing: 2) {
                ForEach(MenuAction.allCases) { action in
                    MenuRow(action: action, isHovered: hoveredAction == action)
                        .onHover { hoveredAction = $0 ? action : nil }
                        .onTapGesture { run(action) }
                }
            }
            .padding(.horizontal, OptuneDesign.Spacing.sm)
            .padding(.vertical, OptuneDesign.Spacing.sm)
        }
        .animation(OptuneDesign.Motion.calm, value: model.primaryDevice?.id)
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
        case .openSettings: return "Open Optune Settings…"
        case .openProject: return "Open project on GitHub"
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
}

// MARK: - Header

private struct HeaderCard: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        HStack(alignment: .center, spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.linearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.accentColor.opacity(0.45), radius: 6, y: 2)
            }
            .frame(width: 42, height: 42)
            .shadow(color: Color.accentColor.opacity(0.25), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Optune").font(OptuneDesign.Typography.title)
                Text("v\(OptuneCore.Optune.version) · \(model.recognizedCount) device\(model.recognizedCount == 1 ? "" : "s")")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
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
            HStack(alignment: .top, spacing: OptuneDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.tint.opacity(0.14))
                    Image(systemName: "computermouse")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.modelName).font(OptuneDesign.Typography.header)
                    HStack(spacing: 6) {
                        Text(String(format: "0x%04X", device.productID))
                            .font(OptuneDesign.Typography.mono)
                            .foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.secondary)
                        Text(device.transport ?? "USB")
                            .font(OptuneDesign.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ConnectionPill()
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
}

private struct ConnectionPill: View {
    var body: some View {
        HStack(spacing: 5) {
            StatusDot(tone: .green, pulse: true)
            Text("Connected")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
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
            label: "DPI",
            secondary: secondary
        ) {
            CapabilityPill(text: pillText, tone: pillTone)
        }
    }

    private var secondary: String? {
        switch state {
        case .ok(_, let lo, let hi, _, _):
            return "Range \(lo) … \(hi)"
        case .unavailable(let why): return why
        case .unknown: return "Reading…"
        }
    }

    private var pillText: String {
        switch state {
        case .ok(let cur, _, _, _, _): return "\(cur)"
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
        HStack(spacing: OptuneDesign.Spacing.sm) {
            Image(systemName: action.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)
            Text(action.label).font(.system(size: 13, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.row, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(OptuneDesign.Motion.glide, value: isHovered)
    }
}
