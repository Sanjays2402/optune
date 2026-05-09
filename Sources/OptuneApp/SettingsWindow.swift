import SwiftUI
import OptuneCore
import OptuneUI

/// Sidebar+detail Settings window — Liquid Glass aesthetic, four panes:
/// Devices · Pointer · Buttons · About. Sliders/toggles wired to live HID++.
struct SettingsWindow: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var selection: Pane = .devices

    enum Pane: String, Hashable, CaseIterable, Identifiable {
        case devices, pointer, buttons, about
        var id: String { rawValue }

        var label: String {
            switch self {
            case .devices: return "Devices"
            case .pointer: return "Pointer"
            case .buttons: return "Buttons"
            case .about:   return "About"
            }
        }
        var symbol: String {
            switch self {
            case .devices: return "computermouse"
            case .pointer: return "scope"
            case .buttons: return "rectangle.grid.2x2"
            case .about:   return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: Binding(
                get: { selection },
                set: { selection = $0 ?? .devices }
            )) { pane in
                Label(pane.label, systemImage: pane.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ZStack {
                LiquidGlassSurface().ignoresSafeArea()
                Group {
                    switch selection {
                    case .devices: DevicesPane()
                    case .pointer: PointerPane()
                    case .buttons: ButtonsPane()
                    case .about:   AboutPane()
                    }
                }
                .padding(OptuneDesign.Spacing.xl)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .navigationTitle("Optune Settings")
    }
}

// MARK: - Devices

private struct DevicesPane: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected devices").font(OptuneDesign.Typography.title)
                    Text("Devices speaking HID++ over Bluetooth or Bolt receiver")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.refresh()
                    model.refreshTelemetryNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .controlSize(.regular)
            }

            if model.recognizedDevices.isEmpty {
                ContentUnavailableView {
                    Label("No supported device", systemImage: "computermouse.fill")
                } description: {
                    Text("Pair an MX Master family mouse via Bluetooth, or plug in a Bolt receiver.")
                } actions: {
                    Button("Refresh") { model.refresh() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassCard(tint: .gray)
            } else {
                ScrollView {
                    VStack(spacing: OptuneDesign.Spacing.md) {
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
    }
}

private struct DeviceDetailCard: View {
    let device: LogitechDevice
    let descriptor: DeviceDescriptor
    let telemetry: DeviceTelemetry
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: "computermouse")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
                    .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(descriptor.modelName).font(OptuneDesign.Typography.header)
                        if isPrimary {
                            CapabilityPill(text: "Primary", tone: .accent)
                        }
                    }
                    Text("PID \(String(format: "0x%04X", device.productID)) · \(device.transport ?? "USB") · \(descriptor.codename)")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    StatLabel("Battery")
                    BatteryStat(state: telemetry.battery)
                }
                GridRow {
                    StatLabel("DPI")
                    DPIStat(state: telemetry.dpi, descriptor: descriptor)
                }
                GridRow {
                    StatLabel("SmartShift")
                    SmartShiftStat(state: telemetry.smartShift)
                }
                GridRow {
                    StatLabel("Buttons")
                    ButtonsStat(state: telemetry.buttons)
                }
                if let serial = device.serialNumber, !serial.isEmpty {
                    GridRow {
                        StatLabel("Serial")
                        Text(serial).font(OptuneDesign.Typography.mono)
                    }
                }
            }
        }
        .glassCard()
    }
}

private struct StatLabel: View {
    let text: String
    init(_ t: String) { self.text = t }
    var body: some View {
        Text(text)
            .font(OptuneDesign.Typography.body)
            .foregroundStyle(.secondary)
            .frame(width: 96, alignment: .leading)
    }
}

private struct BatteryStat: View {
    let state: DeviceTelemetry.Battery
    var body: some View {
        switch state {
        case .ok(let p, let charging, _):
            HStack(spacing: 8) {
                Text("\(p)%").font(OptuneDesign.Typography.body)
                if charging { CapabilityPill(text: "Charging", tone: .positive) }
            }
        case .unavailable(let why):
            Text(why).font(OptuneDesign.Typography.caption).foregroundStyle(.orange)
        case .unknown:
            Text("Reading…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DPIStat: View {
    let state: DeviceTelemetry.DPI
    let descriptor: DeviceDescriptor
    var body: some View {
        switch state {
        case .ok(let cur, let lo, let hi, _, _):
            Text("\(cur) (\(lo)…\(hi))").font(OptuneDesign.Typography.body)
        case .unavailable(let why):
            Text(why).font(OptuneDesign.Typography.caption).foregroundStyle(.orange)
        case .unknown:
            Text("Reading…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
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
                Text("Sensitivity \(t)").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
            }
        case .unavailable(let why):
            Text(why).font(OptuneDesign.Typography.caption).foregroundStyle(.orange)
        case .unknown:
            Text("Reading…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ButtonsStat: View {
    let state: DeviceTelemetry.Buttons
    var body: some View {
        switch state {
        case .ok(let cs):
            Text("\(cs.count) controls · \(cs.filter(\.isReprogrammable).count) reprogrammable")
                .font(OptuneDesign.Typography.body)
        case .unavailable(let why):
            Text(why).font(OptuneDesign.Typography.caption).foregroundStyle(.orange)
        case .unknown:
            Text("Enumerating…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pointer (DPI + SmartShift controls)

private struct PointerPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var dpiDraft: Double?
    @State private var smartshiftDraft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pointer & wheel").font(OptuneDesign.Typography.title)
                Text("Tune sensitivity and SmartShift behaviour for your primary device.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if let descriptor = model.primaryDescriptor {
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
            } else {
                ContentUnavailableView(
                    "No primary device",
                    systemImage: "computermouse.fill",
                    description: Text("Connect an MX Master 3S to tune the pointer and wheel.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassCard(tint: .gray)
            }
            Spacer()
        }
    }
}

private struct DPIControl: View {
    let descriptor: DeviceDescriptor
    let state: DeviceTelemetry.DPI
    @Binding var draft: Double?
    let apply: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Sensitivity (DPI)", systemImage: "scope")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                if let value = currentValue {
                    CapabilityPill(text: "\(value) dpi", tone: .accent)
                }
            }

            if let (cur, lo, hi) = bounds {
                let binding = Binding(
                    get: { draft ?? Double(cur) },
                    set: { draft = $0 }
                )
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
                HStack {
                    Text("\(lo)").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Drag to apply — clamped to firmware range")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(hi)").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Reading DPI from device…").foregroundStyle(.secondary)
            }
        }
        .glassCard()
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
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("SmartShift wheel", systemImage: "wand.and.rays")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

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
                    .disabled(!isEnabled)
                    CapabilityPill(text: "\(Int(binding.wrappedValue))", tone: isEnabled ? .accent : .neutral)
                }
                Text(isEnabled
                     ? "Lower values trip freespin sooner. Higher values keep the wheel notched longer."
                     : "Wheel stays in fixed ratchet — flick speed has no effect."
                )
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
            }
        }
        .glassCard()
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
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reprogrammable buttons").font(OptuneDesign.Typography.title)
                Text("Read-only catalog — runtime remap arrives in v0.4 once permissions land.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if case .ok(let controls) = model.telemetry.buttons {
                ScrollView {
                    VStack(spacing: OptuneDesign.Spacing.sm) {
                        ForEach(controls) { control in
                            ButtonRow(control: control)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No button data", systemImage: "rectangle.grid.2x2")
                } description: {
                    Text(noDataReason)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassCard(tint: .gray)
            }
        }
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(control.isReprogrammable ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(control.isReprogrammable ? Color.accentColor : Color.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(control.name).font(OptuneDesign.Typography.body)
                Text("CID \(String(format: "0x%04X", control.cid))  ·  index \(control.index)  ·  pos \(control.position)")
                    .font(OptuneDesign.Typography.mono)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CapabilityPill(
                text: control.isReprogrammable ? "Reprog" : "Fixed",
                tone: control.isReprogrammable ? .accent : .neutral
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
    var body: some View {
        VStack(spacing: OptuneDesign.Spacing.md) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.linearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 24, y: 6)
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 110, height: 110)

            Text("Optune").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("v\(OptuneCore.Optune.version)")
                .foregroundStyle(.secondary)
                .font(OptuneDesign.Typography.body)
            Text("A modern, open-source Logitech Options+ replacement — native macOS, written in Swift 6.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 60)
            HStack(spacing: 12) {
                Link(destination: URL(string: OptuneCore.Optune.projectURL)!) {
                    Label("github.com/Sanjays2402/optune", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Text("HID++ 2.0 over IOKit — battery, DPI, SmartShift, ReprogControlsV4")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard()
    }
}
