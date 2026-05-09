import SwiftUI
import OptuneCore
import OptuneUI

// MARK: - Wheel pane (HiResWheel + Pointer Speed)

struct WheelPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var speedDraft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Wheel & speed",
                subtitle: "Hi-res scroll modes (0x2121), pointer-speed multiplier (0x2205), and side thumb wheel (0x2150)."
            )

            VStack(alignment: .leading, spacing: OptuneDesign.Spacing.lg) {
                wheelCard
                pointerSpeedCard
                thumbWheelCard
            }
        }
    }

    @ViewBuilder
    private var wheelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Hi-res wheel")
                        .font(OptuneDesign.Typography.header)
                    Spacer()
                    if case .ok(_, _, let mult) = model.telemetry.wheel {
                        CapabilityPill(text: "×\(mult)", tone: .accent)
                    }
                }
                Text("Switches between freespin and ratchet modes; HiResWheel multiplier is a firmware constant per device.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, OptuneDesign.Spacing.md)

            switch model.telemetry.wheel {
            case .ok(let invert, let ratchet, _):
                InsetGroup {
                    InsetRow(
                        title: "Smooth scroll",
                        subtitle: "Off keeps clicky steps; on lets the wheel free-spin."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.teal.opacity(0.14))
                            Image(systemName: "circle.dotted.circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.teal)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: Binding(
                            get: { !ratchet },
                            set: { model.setWheelRatchet(!$0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                    GroupDivider()
                    InsetRow(
                        title: "Invert direction",
                        subtitle: "Up scrolls down — useful if you mirror trackpad direction."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.indigo.opacity(0.14))
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.indigo)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: Binding(
                            get: { invert },
                            set: { model.setWheelInverted($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                }

            case .unavailable(let why):
                infoBlock(why, tone: .warning)
            case .unknown:
                infoBlock("Reading wheel mode…", tone: .neutral)
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

    @ViewBuilder
    private var pointerSpeedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Pointer speed")
                        .font(OptuneDesign.Typography.header)
                    Spacer()
                    if let value = currentSpeed {
                        Text(String(format: "×%.2f", value))
                            .font(OptuneDesign.Typography.value)
                            .foregroundStyle(.tint)
                            .contentTransition(.numericText())
                            .animation(OptuneDesign.Motion.snappy, value: value)
                    }
                }
                Text("Multiplier applied on top of DPI — 1.00× is the firmware default.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, OptuneDesign.Spacing.md)

            if let cur = currentSpeed {
                let binding = Binding(
                    get: { speedDraft ?? cur },
                    set: { speedDraft = $0 }
                )
                VStack(spacing: 6) {
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
                    .tint(.accentColor)
                    HStack {
                        Text("0.4×").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Text("1.0× default").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Text("2.0×").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                    }
                }
            } else {
                infoBlock(unavailableReason, tone: .warning)
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

    @ViewBuilder
    private var thumbWheelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Side thumb wheel")
                        .font(OptuneDesign.Typography.header)
                    Spacer()
                    if case .ok = model.telemetry.thumbWheel {
                        CapabilityPill(text: "0x2150", tone: .accent)
                    }
                }
                Text("MX Master family side wheel. Divert silences native horizontal scroll so macOS won't double-fire; invert flips direction.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, OptuneDesign.Spacing.md)

            switch model.telemetry.thumbWheel {
            case .ok(let diverted, let inverted):
                InsetGroup {
                    InsetRow(
                        title: "Divert thumb wheel",
                        subtitle: "Stops the firmware from sending native horizontal scroll. Useful when macOS double-counts the side wheel."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.purple.opacity(0.14))
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.purple)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: Binding(
                            get: { diverted },
                            set: { model.setThumbWheelDiverted($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                    GroupDivider()
                    InsetRow(
                        title: "Invert direction",
                        subtitle: "Flip the thumb wheel scroll axis."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.pink.opacity(0.14))
                            Image(systemName: "arrow.left.arrow.right.circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.pink)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: Binding(
                            get: { inverted },
                            set: { model.setThumbWheelInverted($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                }

            case .unavailable(let why):
                infoBlock(why, tone: .neutral)
            case .unknown:
                infoBlock("Reading thumb wheel state…", tone: .neutral)
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

    @ViewBuilder
    private func infoBlock(_ text: String, tone: CapabilityPill.Tone) -> some View {
        HStack(spacing: 8) {
            Image(systemName: tone == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(tone.foreground)
                .symbolRenderingMode(.hierarchical)
            Text(text)
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tone.background)
        )
    }
}

// MARK: - Hosts pane (Bolt / multi-host switching)

struct HostsPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var pendingSwitch: UInt8?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Hosts",
                subtitle: "MX-class mice pair with up to three hosts (0x1814 / 0x1815). Tap a slot to move the device."
            )

            switch model.telemetry.hosts {
            case .ok(_, let hosts):
                InsetGroup {
                    ForEach(Array(hosts.enumerated()), id: \.element.id) { idx, host in
                        if idx > 0 { GroupDivider() }
                        HostRow(host: host) {
                            pendingSwitch = host.index
                        }
                    }
                }
            case .unavailable(let why):
                emptyState(why: why)
            case .unknown:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.accentColor)
                    Text("Polling 0x1815…")
                        .font(OptuneDesign.Typography.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(OptuneDesign.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                        .fill(.regularMaterial)
                )
            }
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

    private func emptyState(why: String) -> some View {
        VStack(spacing: OptuneDesign.Spacing.md) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("Hosts unavailable").font(OptuneDesign.Typography.title2)
            Text(why)
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
}

private struct HostRow: View {
    let host: DeviceTelemetry.Host.HostInfo
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconBg)
                Image(systemName: iconSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Host \(host.index + 1)")
                    .font(OptuneDesign.Typography.body)
                Text(host.name.isEmpty ? "—" : host.name)
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            if host.isCurrent {
                CapabilityPill(text: "Current", tone: .positive)
            } else if host.isPaired {
                Button("Switch", action: onSwitch).buttonStyle(.ghost)
            } else {
                CapabilityPill(text: "Empty", tone: .neutral, style: .outline)
            }
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, 10)
    }

    private var iconSymbol: String {
        if host.isCurrent { return "checkmark.circle.fill" }
        return host.isPaired ? "link" : "link.badge.slash"
    }
    private var iconTint: Color {
        if host.isCurrent { return .green }
        return host.isPaired ? .accentColor : .gray
    }
    private var iconBg: Color {
        if host.isCurrent { return Color.green.opacity(0.18) }
        return host.isPaired ? Color.accentColor.opacity(0.16) : Color.gray.opacity(0.10)
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
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "General",
                subtitle: "App-wide preferences and per-device housekeeping."
            )

            // Notifications
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Notifications")
                InsetGroup {
                    InsetRow(
                        title: "Low-battery alerts",
                        subtitle: "One alert per device per drain cycle. Resets when you charge above the threshold."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.orange.opacity(0.14))
                            Image(systemName: "bell.badge")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: $notifyEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: notifyEnabled) { _, new in
                                SettingsStore.shared.updateApp { $0.lowBatteryNotificationsEnabled = new }
                                OptuneNotifications.shared.resetLowBatteryLatch()
                            }
                    }
                    if notifyEnabled {
                        GroupDivider()
                        InsetRow(
                            title: "Threshold",
                            subtitle: "Alert when battery falls below this percentage."
                        ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.red.opacity(0.14))
                                Image(systemName: "battery.25")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                            .frame(width: 22, height: 22)
                        } trailing: {
                            HStack(spacing: 8) {
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
                                .frame(width: 160)
                                Text("\(Int(thresholdDraft))%")
                                    .font(OptuneDesign.Typography.value)
                                    .foregroundStyle(.tint)
                                    .monospacedDigit()
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            // Startup
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Startup")
                InsetGroup {
                    InsetRow(
                        title: "Launch at login",
                        subtitle: LoginItem.isAvailable
                            ? "Optune appears in your menu bar automatically after login."
                            : "Available once Optune runs from a built .app bundle (SMAppService)."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.purple.opacity(0.14))
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.purple)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .disabled(!LoginItem.isAvailable)
                            .onChange(of: launchAtLogin) { _, new in
                                LoginItem.setEnabled(new)
                                SettingsStore.shared.updateApp { $0.launchAtLogin = new }
                            }
                    }
                }
            }

            // Device
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Device")
                InsetGroup {
                    nicknameRow
                    GroupDivider()
                    resetRow
                }
            }
            .alert("Factory-reset device?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { model.factoryReset() }
            } message: {
                Text("This calls 0x0020 reset and clears button assignments, DPI presets, and the friendly name on the device.")
            }
        }
        .onAppear {
            if nicknameDraft.isEmpty {
                nicknameDraft = model.deviceNickname
            }
        }
    }

    private var nicknameRow: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Nickname").font(OptuneDesign.Typography.body)
                Text("Stored on the device via 0x0007. Capped to 14 ASCII chars.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                TextField("Sanjay's MX", text: $nicknameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button("Save") {
                    let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        model.setNickname(trimmed)
                    }
                }
                .buttonStyle(.ghost)
                .disabled(nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, OptuneDesign.Spacing.md)
    }

    private var resetRow: some View {
        HStack(spacing: OptuneDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red.opacity(0.14))
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Factory reset").font(OptuneDesign.Typography.body)
                Text("Erases on-device customizations: DPI presets, button assignments, friendly name, hi-res wheel mode.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset device", systemImage: "exclamationmark.triangle")
            }
            .buttonStyle(.ghost(tint: .red))
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, OptuneDesign.Spacing.md)
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
                    lineWidth: 1.8
                )

                // Fill the area under the curve faintly.
                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(
                    Gradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}
