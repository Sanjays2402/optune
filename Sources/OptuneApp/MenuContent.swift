import SwiftUI
import OptuneCore

/// Menu bar dropdown content. Pure SwiftUI, Liquid-Glass-aware on macOS 26.
struct MenuContent: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var hoveredAction: MenuAction?

    var body: some View {
        VStack(spacing: 0) {
            HeaderCard()
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if let device = model.primaryDevice, let descriptor = model.primaryDescriptor {
                DeviceCard(device: device, descriptor: descriptor, telemetry: model.telemetry)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else {
                EmptyDeviceCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()
                .opacity(0.4)
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                ForEach(MenuAction.allCases) { action in
                    MenuRow(action: action, isHovered: hoveredAction == action)
                        .onHover { hoveredAction = $0 ? action : nil }
                        .onTapGesture { run(action) }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(LiquidGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func run(_ action: MenuAction) {
        switch action {
        case .refresh:
            model.refresh()
            model.refreshTelemetryNow()
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
    case refresh, openProject, quit

    var id: String { rawValue }
    var label: String {
        switch self {
        case .refresh: return "Refresh devices"
        case .openProject: return "Open project on GitHub"
        case .quit: return "Quit Optune"
        }
    }

    var symbol: String {
        switch self {
        case .refresh: return "arrow.clockwise"
        case .openProject: return "arrow.up.right.square"
        case .quit: return "power"
        }
    }
}

private struct HeaderCard: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Optune")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("v\(OptuneCore.Optune.version) · \(model.recognizedCount) device\(model.recognizedCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct DeviceCard: View {
    let device: LogitechDevice
    let descriptor: DeviceDescriptor
    let telemetry: DeviceTelemetry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "computermouse")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.modelName)
                        .font(.system(size: 14, weight: .semibold))
                    Text("PID \(String(format: "0x%04X", device.productID)) · \(device.transport ?? "USB")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: "Connected", tone: .green)
            }

            VStack(alignment: .leading, spacing: 8) {
                BatteryRow(state: telemetry.battery)
                CapabilityRow(symbol: "scope", label: "DPI",     value: "—  pending HID++")
                CapabilityRow(symbol: "wand.and.rays", label: "SmartShift", value: "—  pending HID++")
                CapabilityRow(symbol: "scroll.fill", label: "Smooth scroll", value: descriptor.supportsSmoothScroll ? "Available" : "Not supported")
            }
        }
        .padding(14)
        .background(GlassCardBackground())
    }
}

private struct BatteryRow: View {
    let state: DeviceTelemetry.Battery

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text("Battery")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(displayValue)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
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

    private var displayValue: String {
        switch state {
        case .ok(let p, let charging, let ext):
            let suffix = charging ? " · charging" : (ext ? " · plugged" : "")
            return "\(p)%\(suffix)"
        case .unavailable(let why):
            return why
        case .unknown:
            return "Reading…"
        }
    }
}

private struct EmptyDeviceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No supported device detected", systemImage: "computermouse.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Connect an MX Master 3S via Bluetooth or a Bolt receiver. Optune will appear when it's reachable.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassCardBackground())
    }
}

private struct CapabilityRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusPill: View {
    enum Tone { case green, yellow, red

        var color: Color {
            switch self {
            case .green: return .green
            case .yellow: return .yellow
            case .red: return .red
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct MenuRow: View {
    let action: MenuAction
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(action.label)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

/// Liquid Glass — modern translucent menu surface.
/// Uses the Materials API; on macOS 26 this composes with system glass effects.
private struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.white.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GlassCardBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}
