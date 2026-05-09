import SwiftUI
import OptuneCore
import OptuneUI
import AppKit

/// Settings window — modern macOS-26 sidebar layout with grouped inset lists,
/// proper typography scale, and an action banner for permission issues.
struct SettingsWindow: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var selection: Pane = .devices

    enum Pane: String, Hashable, CaseIterable, Identifiable {
        case devices, pointer, wheel, buttons, hosts, general, about
        var id: String { rawValue }

        var label: String {
            switch self {
            case .devices: return "Devices"
            case .pointer: return "Pointer"
            case .wheel:   return "Wheel"
            case .buttons: return "Buttons"
            case .hosts:   return "Hosts"
            case .general: return "General"
            case .about:   return "About"
            }
        }
        var symbol: String {
            switch self {
            case .devices: return "computermouse"
            case .pointer: return "scope"
            case .wheel:   return "circle.dotted.circle"
            case .buttons: return "rectangle.grid.2x2"
            case .hosts:   return "rectangle.connected.to.line.below"
            case .general: return "gear"
            case .about:   return "info.circle"
            }
        }
        var tint: Color {
            switch self {
            case .devices: return .accentColor
            case .pointer: return .accentColor
            case .wheel:   return .teal
            case .buttons: return .pink
            case .hosts:   return .indigo
            case .general: return .gray
            case .about:   return .accentColor
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
                        if model.permissionMissing {
                            PermissionBanner()
                                .padding(.bottom, OptuneDesign.Spacing.sm)
                        }
                        Group {
                            switch selection {
                            case .devices: DevicesPane()
                            case .pointer: PointerPane()
                            case .wheel:   WheelPane()
                            case .buttons: ButtonsPane()
                            case .hosts:   HostsPane()
                            case .general: GeneralPane()
                            case .about:   AboutPane()
                            }
                        }
                    }
                    .padding(.horizontal, OptuneDesign.Spacing.xxl + 4)
                    .padding(.top, OptuneDesign.Spacing.xl)
                    .padding(.bottom, OptuneDesign.Spacing.xxl)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(minWidth: 880, minHeight: 640)
        .navigationTitle("Optune")
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand block
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.linearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
                .shadow(color: Color.accentColor.opacity(0.30), radius: 5, y: 1)
                Text("Optune")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, OptuneDesign.Spacing.md)
            .padding(.top, OptuneDesign.Spacing.lg)
            .padding(.bottom, OptuneDesign.Spacing.md)

            // Sidebar list with custom rounded selection chip
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Pane.allCases) { pane in
                    SidebarItem(
                        pane: pane,
                        isSelected: selection == pane,
                        action: { selection = pane }
                    )
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Footer status
            VStack(alignment: .leading, spacing: 4) {
                Divider().opacity(0.4)
                HStack(spacing: 6) {
                    StatusDot(tone: model.recognizedCount > 0 ? .green : .gray, pulse: model.recognizedCount > 0)
                    Text(model.recognizedCount > 0
                         ? "\(model.recognizedCount) device\(model.recognizedCount == 1 ? "" : "s") connected"
                         : "No device")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("v\(OptuneCore.Optune.version)")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, OptuneDesign.Spacing.md)
                .padding(.vertical, OptuneDesign.Spacing.sm)
            }
        }
        .background(.ultraThinMaterial)
    }
}

@MainActor
private struct SidebarItem: View {
    let pane: SettingsWindow.Pane
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                Text(pane.label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor
                          : (hover ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(OptuneDesign.Motion.glide, value: isSelected)
        .animation(OptuneDesign.Motion.glide, value: hover)
    }
}

// MARK: - Permission banner

private struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text("Input Monitoring needed")
                    .font(OptuneDesign.Typography.header)
                Text("HID++ telemetry (battery, DPI, SmartShift) needs Input Monitoring access. Grant in System Settings, then return.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.ghost(tint: .orange))
        }
        .padding(OptuneDesign.Spacing.lg - 2)
        .background(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
    }
}

// MARK: - Page header

struct PageHeader: View {
    let title: String
    let subtitle: String
    let trailing: AnyView?

    init<Trailing: View>(_ title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(OptuneDesign.Typography.title)
                Text(subtitle)
                    .font(OptuneDesign.Typography.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Devices

private struct DevicesPane: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Devices",
                subtitle: "HID++ over Bluetooth Low Energy or Logi Bolt receiver."
            ) {
                Button {
                    model.refresh()
                    model.refreshTelemetryNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.ghost)
            }

            if model.recognizedDevices.isEmpty {
                emptyState
            } else {
                VStack(spacing: OptuneDesign.Spacing.lg) {
                    ForEach(model.recognizedDevices) { device in
                        DeviceDetailCard(
                            device: device,
                            descriptor: DeviceRegistry.descriptor(for: device)!,
                            telemetry: model.telemetry,
                            isPrimary: device.id == model.primaryDevice?.id
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No supported device").font(OptuneDesign.Typography.title2)
            Text("Pair an MX Master family mouse via Bluetooth, or plug in a Bolt receiver.")
                .font(OptuneDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh") { model.refresh() }
                .buttonStyle(.ghost)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(OptuneDesign.Spacing.xxl)
        .glassCard(tint: .gray)
    }
}

private struct DeviceDetailCard: View {
    let device: LogitechDevice
    let descriptor: DeviceDescriptor
    let telemetry: DeviceTelemetry
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            // Hero header
            HStack(alignment: .top, spacing: OptuneDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.linearGradient(
                            colors: [Color.accentColor.opacity(0.20), Color.accentColor.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    Image(systemName: "computermouse")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(descriptor.modelName).font(OptuneDesign.Typography.title2)
                        if isPrimary {
                            CapabilityPill(text: "Primary", tone: .accent)
                        }
                    }
                    HStack(spacing: 5) {
                        Text(transportLabel)
                            .font(OptuneDesign.Typography.caption)
                            .foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(String(format: "0x%04X", device.productID))
                            .font(OptuneDesign.Typography.mono)
                            .foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(descriptor.codename)
                            .font(OptuneDesign.Typography.mono)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                ConnectionChip(connected: true)
            }

            // Stats grouped list
            InsetGroup {
                statRow(
                    symbol: "battery.100",
                    tint: .green,
                    label: "Battery",
                    trailing: { BatteryStat(state: telemetry.battery) }
                )
                GroupDivider()
                statRow(
                    symbol: "scope",
                    tint: .accentColor,
                    label: "Pointer",
                    trailing: { DPIStat(state: telemetry.dpi, descriptor: descriptor) }
                )
                GroupDivider()
                statRow(
                    symbol: "wand.and.rays",
                    tint: .purple,
                    label: "SmartShift",
                    trailing: { SmartShiftStat(state: telemetry.smartShift) }
                )
                GroupDivider()
                statRow(
                    symbol: "rectangle.grid.2x2",
                    tint: .pink,
                    label: "Buttons",
                    trailing: { ButtonsStat(state: telemetry.buttons) }
                )
                if let serial = device.serialNumber, !serial.isEmpty {
                    GroupDivider()
                    statRow(
                        symbol: "barcode",
                        tint: .gray,
                        label: "Serial",
                        trailing: {
                            Text(serial).font(OptuneDesign.Typography.mono).foregroundStyle(.secondary)
                        }
                    )
                }
            }

            let samples = SettingsStore.shared.batteryHistory(for: device)
            if samples.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Battery trend")
                            .font(OptuneDesign.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let last = samples.last {
                            Text(last.charging ? "↑ \(last.percent)%" : "\(last.percent)%")
                                .font(OptuneDesign.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    BatterySparkline(samples: samples, height: 40)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
        }
        .padding(OptuneDesign.Spacing.xl)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                    .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.10), radius: 14, y: 4)
    }

    private var transportLabel: String {
        guard let t = device.transport else { return "USB" }
        if t.localizedCaseInsensitiveContains("bluetooth") { return "Bluetooth Low Energy" }
        if t.localizedCaseInsensitiveContains("bolt")      { return "Logi Bolt" }
        return t
    }

    @ViewBuilder
    private func statRow<Trailing: View>(
        symbol: String,
        tint: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 22, height: 22)
            Text(label)
                .font(OptuneDesign.Typography.body)
                .frame(width: 92, alignment: .leading)
            Spacer()
            trailing()
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, 10)
    }
}

private struct BatteryStat: View {
    let state: DeviceTelemetry.Battery
    var body: some View {
        switch state {
        case .ok(let p, let charging, _):
            HStack(spacing: 6) {
                Text("\(p)%").font(OptuneDesign.Typography.value)
                if charging { CapabilityPill(text: "Charging", tone: .positive) }
            }
        case .unavailable:
            CapabilityPill(text: "Unavailable", tone: .warning)
        case .unknown:
            Skeleton(height: 12).frame(width: 60)
        }
    }
}

private struct DPIStat: View {
    let state: DeviceTelemetry.DPI
    let descriptor: DeviceDescriptor
    var body: some View {
        switch state {
        case .ok(let cur, let lo, let hi, _, _):
            HStack(spacing: 6) {
                Text("\(cur) dpi").font(OptuneDesign.Typography.value)
                Text("\(lo)–\(hi)")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        case .unavailable:
            CapabilityPill(text: "Unavailable", tone: .warning)
        case .unknown:
            Skeleton(height: 12).frame(width: 80)
        }
    }
}

private struct SmartShiftStat: View {
    let state: DeviceTelemetry.SmartShift
    var body: some View {
        switch state {
        case .ok(let on, let t, _):
            HStack(spacing: 8) {
                CapabilityPill(text: on ? "On" : "Off", tone: on ? .positive : .neutral)
                Text("Sensitivity \(t)")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        case .unavailable:
            CapabilityPill(text: "Unavailable", tone: .warning)
        case .unknown:
            Skeleton(height: 12).frame(width: 70)
        }
    }
}

private struct ButtonsStat: View {
    let state: DeviceTelemetry.Buttons
    var body: some View {
        switch state {
        case .ok(let cs):
            HStack(spacing: 6) {
                Text("\(cs.count)").font(OptuneDesign.Typography.value)
                Text("(\(cs.filter(\.isReprogrammable).count) reprogrammable)")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        case .unavailable:
            CapabilityPill(text: "Unavailable", tone: .warning)
        case .unknown:
            Skeleton(height: 12).frame(width: 100)
        }
    }
}

// MARK: - Pointer (DPI + SmartShift controls)

private struct PointerPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var dpiDraft: Double?
    @State private var smartshiftDraft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Pointer",
                subtitle: "Tune sensitivity and the SmartShift wheel for your primary device."
            )

            if let descriptor = model.primaryDescriptor {
                VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
                    DPIControl(
                        descriptor: descriptor,
                        state: model.telemetry.dpi,
                        draft: $dpiDraft,
                        apply: { model.applyDPI($0) }
                    )
                    SmartShiftControl(
                        state: model.telemetry.smartShift,
                        draft: $smartshiftDraft,
                        setEnabled: { model.setSmartShiftEnabled($0, threshold: smartshiftDraft.map { UInt8($0) }) },
                        apply: { model.setSmartShiftEnabled(true, threshold: UInt8($0)) }
                    )
                }
            } else {
                NoDeviceState()
            }
        }
    }
}

private struct DPIControl: View {
    let descriptor: DeviceDescriptor
    let state: DeviceTelemetry.DPI
    @Binding var draft: Double?
    let apply: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Sensitivity")
                        .font(OptuneDesign.Typography.header)
                    Spacer()
                    if let value = currentValue {
                        Text("\(value) dpi")
                            .font(OptuneDesign.Typography.value)
                            .foregroundStyle(.tint)
                            .contentTransition(.numericText())
                            .animation(OptuneDesign.Motion.snappy, value: value)
                    }
                }
                Text("Controls how far the pointer moves per inch of mouse travel. Stored on-device, applied immediately.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, OptuneDesign.Spacing.md)

            if let (cur, lo, hi) = bounds {
                let binding = Binding(
                    get: { draft ?? Double(cur) },
                    set: { draft = $0 }
                )
                VStack(spacing: 6) {
                    Slider(
                        value: binding,
                        in: Double(lo)...Double(hi),
                        step: 50,
                        onEditingChanged: { editing in
                            if !editing, let value = draft {
                                apply(Int(value))
                                draft = nil
                            }
                        }
                    )
                    .tint(.accentColor)
                    HStack {
                        Text("\(lo)").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Text("\(hi)").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.accentColor)
                    Text("Reading firmware DPI range…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(OptuneDesign.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 3)
    }

    private var bounds: (Int, Int, Int)? {
        switch state {
        case .ok(let c, let lo, let hi, _, _): return (c, lo, hi)
        default: return nil
        }
    }

    private var currentValue: Int? {
        if let d = draft { return Int(d) }
        if case .ok(let c, _, _, _, _) = state { return c }
        return nil
    }
}

private struct SmartShiftControl: View {
    let state: DeviceTelemetry.SmartShift
    @Binding var draft: Double?
    let setEnabled: (Bool) -> Void
    let apply: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("SmartShift wheel")
                        .font(OptuneDesign.Typography.header)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
                Text("Flick the wheel and it free-spins; nudge it and it ratchets. Adjust the threshold to taste.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, OptuneDesign.Spacing.md)

            if let threshold = currentThreshold {
                let binding = Binding(
                    get: { draft ?? Double(threshold) },
                    set: { draft = $0 }
                )
                HStack(spacing: 12) {
                    Slider(
                        value: binding,
                        in: 1...50,
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing, let v = draft {
                                apply(v); draft = nil
                            }
                        }
                    )
                    .tint(isEnabled ? .accentColor : .gray)
                    .disabled(!isEnabled)
                    Text("\(Int(binding.wrappedValue))")
                        .font(OptuneDesign.Typography.value)
                        .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                        .contentTransition(.numericText())
                        .animation(OptuneDesign.Motion.snappy, value: binding.wrappedValue)
                }
                HStack {
                    Text("Sensitive")
                        .font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                    Spacer()
                    Text("Sticky")
                        .font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(OptuneDesign.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 3)
    }

    private var isEnabled: Bool {
        if case .ok(let on, _, _) = state { return on } else { return false }
    }

    private var currentThreshold: UInt8? {
        if case .ok(_, let t, _) = state { return t } else { return nil }
    }
}

// MARK: - Buttons

private struct ButtonsPane: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Buttons",
                subtitle: "Read-only catalog of reprogrammable controls. Runtime remap arrives in v0.5."
            )

            if case .ok(let controls) = model.telemetry.buttons {
                InsetGroup {
                    ForEach(Array(controls.enumerated()), id: \.element.id) { idx, control in
                        if idx > 0 { GroupDivider() }
                        ButtonRow(control: control)
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No button data").font(OptuneDesign.Typography.title2)
            Text(noDataReason)
                .font(OptuneDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.refreshTelemetryNow()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.ghost)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(OptuneDesign.Spacing.xxl)
        .glassCard(tint: .gray)
    }

    private var noDataReason: String {
        switch model.telemetry.buttons {
        case .unavailable(let why): return why
        case .unknown: return "Polling device for ReprogControlsV4 (0x1B04)…"
        case .ok: return ""
        }
    }
}

private struct ButtonRow: View {
    let control: DeviceTelemetry.SerializableControl

    var body: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(control.isReprogrammable ? Color.accentColor.opacity(0.16) : Color.gray.opacity(0.10))
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(control.isReprogrammable ? Color.accentColor : Color.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(control.name).font(OptuneDesign.Typography.body)
                Text("CID \(String(format: "0x%04X", control.cid)) · idx \(control.index) · pos \(control.position)")
                    .font(OptuneDesign.Typography.mono)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            CapabilityPill(
                text: control.isReprogrammable ? "Reprog" : "Fixed",
                tone: control.isReprogrammable ? .accent : .neutral
            )
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, 10)
    }

    private var symbol: String {
        if control.name.contains("Click") { return "cursorarrow.click" }
        if control.name.contains("DPI") { return "scope" }
        if control.name.contains("Smart") { return "wand.and.rays" }
        if control.name.contains("Gesture") { return "hand.draw" }
        if control.name.contains("Tilt") { return "arrow.left.arrow.right" }
        if control.name.contains("Back") { return "arrow.uturn.backward" }
        if control.name.contains("Forward") { return "arrow.uturn.forward" }
        return "rectangle.grid.2x2"
    }
}

// MARK: - About

private struct AboutPane: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(spacing: OptuneDesign.Spacing.xl) {
            // Hero
            VStack(spacing: OptuneDesign.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.linearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.50)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.accentColor.opacity(0.45), radius: 20, y: 6)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.20), radius: 4, y: 1)
                }
                .frame(width: 92, height: 92)

                VStack(spacing: 6) {
                    Text("Optune").font(OptuneDesign.Typography.display)
                    HStack(spacing: 8) {
                        Text("v\(OptuneCore.Optune.version)")
                            .font(OptuneDesign.Typography.body)
                            .foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.tertiary)
                        Text("GPL-3.0")
                            .font(OptuneDesign.Typography.body)
                            .foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.tertiary)
                        Text("Swift 6 · macOS 14+")
                            .font(OptuneDesign.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("A modern, open-source replacement for Logitech Options+. Native macOS, no Electron, no telemetry.")
                    .font(OptuneDesign.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                HStack(spacing: 8) {
                    Link(destination: URL(string: OptuneCore.Optune.projectURL)!) {
                        Label("GitHub", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.ghost)
                    if let issuesURL = URL(string: OptuneCore.Optune.projectURL + "/issues") {
                        Link(destination: issuesURL) {
                            Label("Report an issue", systemImage: "ant")
                        }
                        .buttonStyle(.ghost)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, OptuneDesign.Spacing.lg)

            // Connected device card
            connectedDeviceCard

            // Capabilities chips
            capabilitiesCard

            // Credits
            VStack(spacing: 4) {
                Text("Built by Sanjay Santhanam")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                Text("© 2026 · Made for the people who miss simple peripherals.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, OptuneDesign.Spacing.lg)
        }
    }

    @ViewBuilder
    private var connectedDeviceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Connected device")
            InsetGroup {
                if let device = model.primaryDevice, let descriptor = model.primaryDescriptor {
                    aboutRow("Model", descriptor.modelName, mono: false)
                    GroupDivider()
                    aboutRow("Codename", descriptor.codename, mono: true)
                    GroupDivider()
                    aboutRow("Product ID", String(format: "0x%04X", device.productID), mono: true)
                    GroupDivider()
                    aboutRow("Transport", device.transport ?? "USB", mono: false)
                    if let serial = device.serialNumber, !serial.isEmpty {
                        GroupDivider()
                        aboutRow("Serial", serial, mono: true)
                    }
                    if !model.deviceNickname.isEmpty {
                        GroupDivider()
                        aboutRow("Nickname", model.deviceNickname, mono: false)
                    }
                    if case .ok(let entities, _) = model.telemetry.firmware {
                        ForEach(entities) { entity in
                            GroupDivider()
                            aboutRow(entity.kind, entity.displayVersion, mono: true)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "computermouse.fill")
                            .foregroundStyle(.tertiary)
                        Text("No device connected.").foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
                    .padding(.vertical, OptuneDesign.Spacing.md)
                }
            }
        }
    }

    private func aboutRow(_ label: String, _ value: String, mono: Bool) -> some View {
        HStack {
            Text(label)
                .font(OptuneDesign.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Spacer()
            Text(value)
                .font(mono ? OptuneDesign.Typography.mono : OptuneDesign.Typography.value)
                .textSelection(.enabled)
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, 10)
    }

    private var capabilitiesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Capabilities")
            VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
                Text("HID++ 2.0 over IOKit")
                    .font(OptuneDesign.Typography.body)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(capabilities, id: \.self) { cap in
                        CapabilityPill(text: cap, tone: .accent, style: .outline)
                    }
                }
            }
            .padding(OptuneDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                    .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
            )
        }
    }

    private var capabilities: [String] {
        ["Battery", "DPI", "SmartShift", "ReprogControlsV4", "FirmwareInfo", "Hosts", "HiResWheel", "PointerSpeed"]
    }
}

// MARK: - Shared empty states

@MainActor
private struct NoDeviceState: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("No primary device").font(OptuneDesign.Typography.title2)
            Text("Connect an MX Master 3S to tune the pointer and wheel.")
                .font(OptuneDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh") {
                model.refresh()
                model.refreshTelemetryNow()
            }
            .buttonStyle(.ghost)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(OptuneDesign.Spacing.xxl)
        .glassCard(tint: .gray)
    }
}

// MARK: - Flow layout for capability chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalH: CGFloat = 0
        var maxX: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - spacing)
            totalH = y + lineHeight
        }
        return CGSize(width: min(maxW, maxX), height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
