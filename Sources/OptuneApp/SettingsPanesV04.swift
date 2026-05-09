import SwiftUI
import OptuneCore
import OptuneUI

// MARK: - Wheel pane (HiResWheel + Pointer Speed)

struct WheelPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var speedDraft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wheel & speed").font(OptuneDesign.Typography.title)
                Text("Hi-res scroll modes (0x2121) and the pointer-speed multiplier (0x2205).")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            wheelCard
            pointerSpeedCard

            Spacer()
        }
    }

    @ViewBuilder
    private var wheelCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Hi-res wheel", systemImage: "circle.dotted.circle")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                if case .ok(_, _, let mult) = model.telemetry.wheel {
                    CapabilityPill(text: "×\(mult)", tone: .accent)
                }
            }

            switch model.telemetry.wheel {
            case .ok(let invert, let ratchet, _):
                Toggle("Smooth scroll (freespin off)", isOn: Binding(
                    get: { ratchet },
                    set: { model.setWheelRatchet($0) }
                )).toggleStyle(.switch)
                Toggle("Invert scroll direction", isOn: Binding(
                    get: { invert },
                    set: { model.setWheelInverted($0) }
                )).toggleStyle(.switch)
                Text(ratchet
                     ? "Wheel is in ratchet mode — clicky steps."
                     : "Wheel is in freespin — flick once and it spins for ages.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)

            case .unavailable(let why):
                Text(why).font(OptuneDesign.Typography.caption).foregroundStyle(.orange)
            case .unknown:
                Text("Reading wheel mode…").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private var pointerSpeedCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Pointer speed", systemImage: "speedometer")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                if let value = currentSpeed {
                    CapabilityPill(text: String(format: "×%.2f", value), tone: .accent)
                }
            }

            if let cur = currentSpeed {
                let binding = Binding(
                    get: { speedDraft ?? cur },
                    set: { speedDraft = $0 }
                )
                Slider(
                    value: binding,
                    in: 0.4...2.0,
                    step: 0.1,
                    onEditingChanged: { editing in
                        if !editing, let v = speedDraft {
                            model.setPointerSpeed(v)
                            speedDraft = nil
                        }
                    }
                )
                HStack {
                    Text("0.4×").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Multiplier applied on top of DPI")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("2.0×").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(unavailableReason)
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.orange)
            }
        }
        .glassCard()
    }

    private var currentSpeed: Double? {
        if case .ok(_, let m) = model.telemetry.pointerSpeed { return m }
        return nil
    }

    private var unavailableReason: String {
        switch model.telemetry.pointerSpeed {
        case .unavailable(let why): return why
        case .unknown: return "Reading…"
        case .ok: return ""
        }
    }
}

// MARK: - Hosts pane (Bolt / multi-host switching)

struct HostsPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var pendingSwitch: UInt8?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hosts").font(OptuneDesign.Typography.title)
                Text("MX-class mice pair with up to three hosts (0x1814 / 0x1815). Tap a slot to move the device.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            switch model.telemetry.hosts {
            case .ok(_, let hosts):
                ScrollView {
                    VStack(spacing: OptuneDesign.Spacing.sm) {
                        ForEach(hosts) { host in
                            HostRow(host: host) {
                                pendingSwitch = host.index
                            }
                        }
                    }
                }
            case .unavailable(let why):
                ContentUnavailableView {
                    Label("Hosts unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(why)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassCard(tint: .gray)
            case .unknown:
                ProgressView("Polling 0x1815…").frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .alert("Switch host?", isPresented: Binding(
            get: { pendingSwitch != nil },
            set: { if !$0 { pendingSwitch = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
            Button("Switch", role: .destructive) {
                if let idx = pendingSwitch {
                    model.switchHost(to: idx)
                }
                pendingSwitch = nil
            }
        } message: {
            Text("The mouse will drop from this Mac and try the selected host. Optune will refresh once it reconnects here.")
        }
    }
}

private struct HostRow: View {
    let host: DeviceTelemetry.Host.HostInfo
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(host.isCurrent
                          ? Color.accentColor.opacity(0.22)
                          : (host.isPaired ? Color.gray.opacity(0.16) : Color.red.opacity(0.10)))
                Image(systemName: host.isCurrent ? "checkmark.circle.fill" : (host.isPaired ? "link" : "link.badge.slash"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(host.isCurrent ? .green : (host.isPaired ? .accentColor : .red))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Host \(host.index + 1)").font(OptuneDesign.Typography.body)
                Text(host.name).font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if host.isCurrent {
                CapabilityPill(text: "Current", tone: .positive)
            } else if host.isPaired {
                Button("Switch", action: onSwitch).controlSize(.small)
            } else {
                CapabilityPill(text: "Empty", tone: .neutral)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - General (notifications, login item, factory reset, nickname)

struct GeneralPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var notifyEnabled: Bool = SettingsStore.shared.app.lowBatteryNotificationsEnabled
    @State private var thresholdDraft: Double = Double(SettingsStore.shared.app.lowBatteryThreshold)
    @State private var launchAtLogin: Bool = LoginItem.isEnabled
    @State private var nicknameDraft: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("General").font(OptuneDesign.Typography.title)
                    Text("App-wide preferences and per-device housekeeping.")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                notificationsCard
                launchCard
                nicknameCard
                resetCard
            }
        }
        .alert("Factory-reset device?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { model.factoryReset() }
        } message: {
            Text("This calls 0x0020 reset and clears button assignments, DPI presets, and the friendly name on the device.")
        }
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Low-battery notifications", systemImage: "bell.badge")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                Toggle("", isOn: $notifyEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: notifyEnabled) { _, new in
                        SettingsStore.shared.updateApp { $0.lowBatteryNotificationsEnabled = new }
                        OptuneNotifications.shared.resetLowBatteryLatch()
                    }
            }
            if notifyEnabled {
                HStack {
                    Text("Threshold")
                    Slider(
                        value: $thresholdDraft,
                        in: 5...50,
                        step: 5,
                        onEditingChanged: { editing in
                            if !editing {
                                SettingsStore.shared.updateApp {
                                    $0.lowBatteryThreshold = Int(thresholdDraft)
                                }
                                OptuneNotifications.shared.resetLowBatteryLatch()
                            }
                        }
                    )
                    CapabilityPill(text: "\(Int(thresholdDraft))%", tone: .accent)
                }
            }
            Text("We deliver one alert per device per drain cycle. Once you charge above the threshold the latch resets.")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var launchCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Launch at login", systemImage: "power")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!LoginItem.isAvailable)
                    .onChange(of: launchAtLogin) { _, new in
                        LoginItem.setEnabled(new)
                        SettingsStore.shared.updateApp { $0.launchAtLogin = new }
                    }
            }
            Text(LoginItem.isAvailable
                 ? "Optune appears in your menu bar automatically after login."
                 : "Available once Optune is run from a built .app bundle (SMAppService requirement).")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var nicknameCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Device nickname", systemImage: "tag")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                if !model.deviceNickname.isEmpty {
                    CapabilityPill(text: model.deviceNickname, tone: .accent)
                }
            }
            HStack {
                TextField("e.g. Sanjay's MX", text: $nicknameDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        model.setNickname(trimmed)
                    }
                }
                .disabled(nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Stored on the device via 0x0007. Capped to 14 ASCII chars. Other Logitech apps will see it too.")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
        .onAppear {
            if nicknameDraft.isEmpty {
                nicknameDraft = model.deviceNickname
            }
        }
    }

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.md) {
            HStack {
                Label("Factory reset", systemImage: "arrow.counterclockwise.circle")
                    .font(OptuneDesign.Typography.header)
                Spacer()
            }
            Text("Erases on-device customizations: DPI presets, button assignments, friendly name, hi-res wheel mode.")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset device", systemImage: "exclamationmark.triangle")
                }
                .controlSize(.regular)
            }
        }
        .glassCard()
    }
}

// MARK: - Battery sparkline (used in DevicesPane and About)

struct BatterySparkline: View {
    let samples: [BatterySample]
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard samples.count >= 2 else { return }
                let xs = samples.enumerated().map { idx, _ in
                    CGFloat(idx) / CGFloat(samples.count - 1) * size.width
                }
                let ys = samples.map { sample in
                    (1 - CGFloat(sample.percent) / 100.0) * size.height
                }

                var line = Path()
                line.move(to: CGPoint(x: xs[0], y: ys[0]))
                for i in 1..<samples.count {
                    line.addLine(to: CGPoint(x: xs[i], y: ys[i]))
                }
                ctx.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [.green, .accentColor]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    lineWidth: 1.6
                )

                // Fill the area under the curve faintly.
                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .color(.accentColor.opacity(0.08)))
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}
