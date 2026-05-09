import SwiftUI
import AppKit
import OptuneCore
import OptuneUI

// MARK: - App Profiles pane

struct AppProfilesPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var enabled: Bool = SettingsStore.shared.app.appProfilesEnabled
    @State private var showPicker: Bool = false
    @State private var editingProfile: AppProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "App Profiles",
                subtitle: "Pin DPI, pointer speed, SmartShift, and wheel behavior to specific apps. Switching apps re-applies the matching profile automatically."
            )

            // Master toggle
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Auto-switch")
                InsetGroup {
                    InsetRow(
                        title: "Apply profile when frontmost app changes",
                        subtitle: enabled
                            ? "Watching for app activations…"
                            : "Profiles are saved but never auto-applied while disabled."
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.orange.opacity(0.14))
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        .frame(width: 22, height: 22)
                    } trailing: {
                        Toggle("", isOn: $enabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: enabled) { _, new in
                                model.appProfileManager.setEnabled(new)
                            }
                    }
                }
            }

            // Profile list
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeader("Profiles")
                    Spacer()
                    Button {
                        editingProfile = AppProfile(name: "New profile", bundleIDs: [])
                    } label: {
                        Label("New profile", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tint)
                }
                .padding(.bottom, 4)

                if model.appProfileManager.profiles.isEmpty {
                    InsetGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No profiles yet")
                                .font(OptuneDesign.Typography.body)
                            Text("Add a profile to bind a DPI/SmartShift preset to an app like Figma, Xcode, or Final Cut Pro. Profiles with no app are treated as the global default.")
                                .font(OptuneDesign.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    InsetGroup {
                        ForEach(model.appProfileManager.profiles) { profile in
                            ProfileRow(
                                profile: profile,
                                isActive: model.appProfileManager.activeProfileID == profile.id,
                                onEdit: { editingProfile = profile },
                                onDelete: { model.appProfileManager.remove(profile) }
                            )
                            if profile.id != model.appProfileManager.profiles.last?.id {
                                GroupDivider()
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditor(profile: profile) { updated in
                model.appProfileManager.upsert(updated)
                editingProfile = nil
            } cancel: {
                editingProfile = nil
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: AppProfile
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((isActive ? Color.green : Color.orange).opacity(0.14))
                Image(systemName: profile.bundleIDs.isEmpty ? "globe" : "app.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.green : Color.orange)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(OptuneDesign.Typography.body)
                    if isActive {
                        Text("active")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.green.opacity(0.18))
                            )
                            .foregroundStyle(.green)
                    }
                }
                Text(summary)
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit profile")
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete profile")
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        var parts: [String] = []
        if profile.bundleIDs.isEmpty {
            parts.append("Default (no app match)")
        } else {
            parts.append(profile.bundleIDs.prefix(2).joined(separator: ", "))
            if profile.bundleIDs.count > 2 {
                parts.append("+\(profile.bundleIDs.count - 2)")
            }
        }
        if let dpi = profile.dpi { parts.append("\(dpi) DPI") }
        if let speed = profile.pointerSpeed {
            parts.append(String(format: "speed %.1fx", speed))
        }
        if profile.smartShiftEnabled == true { parts.append("SmartShift on") }
        if profile.smartShiftEnabled == false { parts.append("SmartShift off") }
        if profile.wheelInverted == true { parts.append("wheel inverted") }
        if profile.wheelRatchet == false { parts.append("freespin wheel") }
        return parts.joined(separator: " • ")
    }
}

private struct ProfileEditor: View {
    @State var profile: AppProfile
    let save: (AppProfile) -> Void
    let cancel: () -> Void

    @State private var dpiEnabled = false
    @State private var dpiValue: Int = 1000
    @State private var speedEnabled = false
    @State private var speedValue: Double = 1.0
    @State private var smartEnabled = false
    @State private var smartOn: Bool = true
    @State private var smartThreshold: Double = 25
    @State private var wheelInvEnabled = false
    @State private var wheelInverted: Bool = false
    @State private var wheelRatchetEnabled = false
    @State private var wheelRatchet: Bool = true
    @State private var apps: [InstalledApp] = []
    @State private var bundleSelection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Profile").font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        Text("Name").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        TextField("Profile name", text: $profile.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    Group {
                        Text("Apps").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text("Leave empty to make this the default catch-all profile.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(apps) { app in
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { bundleSelection.contains(app.id) },
                                            set: { isOn in
                                                if isOn { bundleSelection.insert(app.id) }
                                                else { bundleSelection.remove(app.id) }
                                            }
                                        )) {
                                            HStack(spacing: 8) {
                                                Text(app.name).font(.system(size: 12))
                                                Text(app.id).font(.system(size: 10)).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                        .frame(height: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }

                    Group {
                        Text("Settings").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)

                        Toggle("Set DPI", isOn: $dpiEnabled)
                        if dpiEnabled {
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(dpiValue) },
                                    set: { dpiValue = Int($0) }
                                ), in: 200...8000, step: 50)
                                Text("\(dpiValue)").monospacedDigit().frame(width: 60, alignment: .trailing)
                            }
                        }

                        Toggle("Set pointer speed", isOn: $speedEnabled)
                        if speedEnabled {
                            HStack {
                                Slider(value: $speedValue, in: 0.5...3.0, step: 0.1)
                                Text(String(format: "%.1fx", speedValue))
                                    .monospacedDigit()
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }

                        Toggle("Set SmartShift", isOn: $smartEnabled)
                        if smartEnabled {
                            Toggle("SmartShift enabled", isOn: $smartOn)
                            if smartOn {
                                HStack {
                                    Slider(value: $smartThreshold, in: 1...50, step: 1)
                                    Text("\(Int(smartThreshold))").monospacedDigit().frame(width: 40, alignment: .trailing)
                                }
                            }
                        }

                        Toggle("Set wheel direction", isOn: $wheelInvEnabled)
                        if wheelInvEnabled {
                            Toggle("Inverted (natural scroll)", isOn: $wheelInverted)
                        }

                        Toggle("Set wheel mode", isOn: $wheelRatchetEnabled)
                        if wheelRatchetEnabled {
                            Toggle("Ratchet (notched)", isOn: $wheelRatchet)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { cancel() }
                Button("Save") {
                    var p = profile
                    p.bundleIDs = Array(bundleSelection)
                    p.dpi = dpiEnabled ? dpiValue : nil
                    p.pointerSpeed = speedEnabled ? speedValue : nil
                    p.smartShiftEnabled = smartEnabled ? smartOn : nil
                    p.smartShiftThreshold = smartEnabled ? UInt8(clamping: Int(smartThreshold)) : nil
                    p.wheelInverted = wheelInvEnabled ? wheelInverted : nil
                    p.wheelRatchet = wheelRatchetEnabled ? wheelRatchet : nil
                    save(p)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(width: 540, height: 620)
        .onAppear {
            apps = InstalledApp.discover()
            bundleSelection = Set(profile.bundleIDs)
            dpiEnabled = profile.dpi != nil
            dpiValue = profile.dpi ?? 1000
            speedEnabled = profile.pointerSpeed != nil
            speedValue = profile.pointerSpeed ?? 1.0
            smartEnabled = profile.smartShiftEnabled != nil
            smartOn = profile.smartShiftEnabled ?? true
            smartThreshold = Double(profile.smartShiftThreshold ?? 25)
            wheelInvEnabled = profile.wheelInverted != nil
            wheelInverted = profile.wheelInverted ?? false
            wheelRatchetEnabled = profile.wheelRatchet != nil
            wheelRatchet = profile.wheelRatchet ?? true
        }
    }
}

// MARK: - Keyboard pane (backlight + Fn-lock)

struct KeyboardPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var blEnabled: Bool = false
    @State private var blMode: UInt8 = 1
    @State private var blLevel: Double = 4
    @State private var blMax: UInt8 = 7
    @State private var fnLockOn: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Keyboard",
                subtitle: "Backlight, Fn-lock, and other keyboard-only behavior. Available on MX Keys S, MX Mechanical, and Pop Keys."
            )

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Backlight")
                InsetGroup {
                    if case .ok(_, _, _, let maxLevel) = model.telemetry.backlight {
                        InsetRow(
                            title: "Backlight",
                            subtitle: "Turn the keyboard backlight on or off."
                        ) {
                            iconBlock("light.max", tint: .mint)
                        } trailing: {
                            Toggle("", isOn: $blEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: blEnabled) { _, new in
                                    model.setBacklight(enabled: new, mode: blMode, level: UInt8(blLevel))
                                }
                        }
                        if blEnabled {
                            GroupDivider()
                            InsetRow(
                                title: "Mode",
                                subtitle: "Auto fades when you stop typing. Always on holds at the level below."
                            ) {
                                iconBlock("sun.max", tint: .yellow)
                            } trailing: {
                                Picker("", selection: $blMode) {
                                    Text("Auto").tag(UInt8(1))
                                    Text("Always on").tag(UInt8(2))
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                                .labelsHidden()
                                .onChange(of: blMode) { _, new in
                                    model.setBacklight(enabled: blEnabled, mode: new, level: UInt8(blLevel))
                                }
                            }
                            GroupDivider()
                            InsetRow(
                                title: "Brightness",
                                subtitle: "Level 0 = off. Top of range varies by model (typically 7)."
                            ) {
                                iconBlock("dial.high", tint: .orange)
                            } trailing: {
                                HStack(spacing: 8) {
                                    Slider(value: $blLevel, in: 0...Double(blMax), step: 1, onEditingChanged: { editing in
                                        if !editing {
                                            model.setBacklight(enabled: blEnabled, mode: blMode, level: UInt8(blLevel))
                                        }
                                    })
                                    .frame(width: 160)
                                    Text("\(Int(blLevel))/\(blMax)")
                                        .font(OptuneDesign.Typography.value)
                                        .monospacedDigit()
                                        .frame(width: 44, alignment: .trailing)
                                }
                            }
                        }
                        let _ = maxLevel  // captured into onAppear below
                    } else {
                        UnavailableRow(reason: backlightReason)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Fn-lock")
                InsetGroup {
                    if case .ok(_, _, let invertible) = model.telemetry.fnLock {
                        InsetRow(
                            title: "F-keys produce F1–F12",
                            subtitle: invertible
                                ? "When off, the F-row defaults to brightness, volume, and other media keys."
                                : "Read-only: this keyboard reports Fn-lock as not user-invertible."
                        ) {
                            iconBlock("keyboard", tint: .indigo)
                        } trailing: {
                            Toggle("", isOn: $fnLockOn)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .disabled(!invertible)
                                .onChange(of: fnLockOn) { _, new in
                                    model.setFnLock(new)
                                }
                        }
                    } else {
                        UnavailableRow(reason: fnLockReason)
                    }
                }
            }
        }
        .onAppear { hydrateFromTelemetry() }
        .onChange(of: model.telemetry.backlight) { _, _ in hydrateFromTelemetry() }
        .onChange(of: model.telemetry.fnLock) { _, _ in hydrateFromTelemetry() }
    }

    private var backlightReason: String {
        if case .unavailable(let why) = model.telemetry.backlight { return why }
        return "Backlight feature 0x1982 not exposed by this device."
    }
    private var fnLockReason: String {
        if case .unavailable(let why) = model.telemetry.fnLock { return why }
        return "Fn-lock feature 0x40A3 not exposed by this device."
    }

    private func hydrateFromTelemetry() {
        if case .ok(let enabled, let mode, let level, let max) = model.telemetry.backlight {
            blEnabled = enabled
            blMode = mode == 0 ? 1 : mode
            blLevel = Double(level)
            blMax = max == 0 ? 7 : max
        }
        if case .ok(_, let on, _) = model.telemetry.fnLock {
            fnLockOn = on
        }
    }
}

// MARK: - Onboard pane

struct OnboardPane: View {
    @EnvironmentObject private var model: DeviceModel
    @State private var mode: UInt8 = 2
    @State private var slot: UInt8 = 1

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Onboard Profiles",
                subtitle: "Switch the mouse between host-driven mode (Optune controls every setting) and onboard mode (the mouse runs from its own flash)."
            )

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Profile mode")
                InsetGroup {
                    if case .ok(_, _, let count) = model.telemetry.onboard {
                        InsetRow(
                            title: "Run from",
                            subtitle: "Host mode uses the settings above. Onboard runs the slot you pick below — settings persist with the mouse across machines."
                        ) {
                            iconBlock("internaldrive", tint: .purple)
                        } trailing: {
                            Picker("", selection: $mode) {
                                Text("Host").tag(UInt8(2))
                                Text("Onboard").tag(UInt8(1))
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .labelsHidden()
                            .onChange(of: mode) { _, new in
                                model.setOnboardMode(new)
                            }
                        }

                        if mode == 1, count > 0 {
                            GroupDivider()
                            InsetRow(
                                title: "Active slot",
                                subtitle: "The mouse stores up to \(count) profile\(count == 1 ? "" : "s") in flash. Slot 1 is the factory default."
                            ) {
                                iconBlock("number.circle", tint: .pink)
                            } trailing: {
                                Picker("", selection: $slot) {
                                    ForEach(1...max(count, 1), id: \.self) { i in
                                        Text("Slot \(i)").tag(UInt8(i))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 130)
                                .labelsHidden()
                                .onChange(of: slot) { _, new in
                                    model.setOnboardActiveProfile(new)
                                }
                            }
                        }
                    } else {
                        UnavailableRow(reason: onboardReason)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Status")
                InsetGroup {
                    InsetRow(
                        title: "Current state",
                        subtitle: onboardStatusSubtitle
                    ) {
                        iconBlock("dot.radiowaves.left.and.right", tint: .green)
                    } trailing: {
                        EmptyView()
                    }
                }
            }

            Text("Caveat: writing custom button maps and DPI tables to flash is intentionally not exposed yet — Optune lets you switch the mouse to onboard mode and pick a slot, but the slot contents are whatever the factory or a previous tool left there.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { hydrate() }
        .onChange(of: model.telemetry.onboard) { _, _ in hydrate() }
    }

    private var onboardReason: String {
        if case .unavailable(let why) = model.telemetry.onboard { return why }
        return "Onboard profiles feature 0x8100 not exposed by this device."
    }

    private var onboardStatusSubtitle: String {
        guard case .ok(let m, let active, let count) = model.telemetry.onboard else {
            return "—"
        }
        let modeName = m == 1 ? "Onboard" : (m == 2 ? "Host" : "Unknown")
        return "Mode: \(modeName) • Active slot: \(active) • Slots available: \(count)"
    }

    private func hydrate() {
        if case .ok(let m, let active, _) = model.telemetry.onboard {
            mode = m == 0 ? 2 : m
            slot = max(active, 1)
        }
    }
}

// MARK: - Notifications pane

struct NotificationsPane: View {
    @State private var lowBattery: Bool = SettingsStore.shared.app.lowBatteryNotificationsEnabled
    @State private var threshold: Double = Double(SettingsStore.shared.app.lowBatteryThreshold)
    @State private var connectionAlerts: Bool = SettingsStore.shared.app.connectionNotificationsEnabled
    @State private var hostAlerts: Bool = SettingsStore.shared.app.hostSwitchNotificationsEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Notifications",
                subtitle: "Optune uses macOS notifications. Toggle each category here; granular delivery (banners, sound, focus) lives in System Settings ▸ Notifications ▸ Optune."
            )

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Battery")
                InsetGroup {
                    InsetRow(
                        title: "Low-battery alerts",
                        subtitle: "Fires once per drain cycle when a device drops below the threshold."
                    ) {
                        iconBlock("battery.25", tint: .red)
                    } trailing: {
                        Toggle("", isOn: $lowBattery)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: lowBattery) { _, new in
                                SettingsStore.shared.updateApp { $0.lowBatteryNotificationsEnabled = new }
                                OptuneNotifications.shared.resetLowBatteryLatch()
                            }
                    }
                    if lowBattery {
                        GroupDivider()
                        InsetRow(
                            title: "Threshold",
                            subtitle: "Alert when battery falls below this percentage."
                        ) {
                            iconBlock("gauge.with.dots.needle.bottom.50percent", tint: .orange)
                        } trailing: {
                            HStack(spacing: 8) {
                                Slider(value: $threshold, in: 5...50, step: 5,
                                       onEditingChanged: { editing in
                                    if !editing {
                                        SettingsStore.shared.updateApp { $0.lowBatteryThreshold = Int(threshold) }
                                        OptuneNotifications.shared.resetLowBatteryLatch()
                                    }
                                })
                                .frame(width: 160)
                                Text("\(Int(threshold))%")
                                    .font(OptuneDesign.Typography.value)
                                    .monospacedDigit()
                                    .foregroundStyle(.tint)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Device events")
                InsetGroup {
                    InsetRow(
                        title: "Connection changes",
                        subtitle: "Alert when a device reconnects after a wireless dropout."
                    ) {
                        iconBlock("wave.3.right", tint: .green)
                    } trailing: {
                        Toggle("", isOn: $connectionAlerts)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: connectionAlerts) { _, new in
                                SettingsStore.shared.updateApp { $0.connectionNotificationsEnabled = new }
                            }
                    }
                    GroupDivider()
                    InsetRow(
                        title: "Host switches",
                        subtitle: "Alert when a multi-host device flips to a different paired computer."
                    ) {
                        iconBlock("rectangle.connected.to.line.below", tint: .indigo)
                    } trailing: {
                        Toggle("", isOn: $hostAlerts)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: hostAlerts) { _, new in
                                SettingsStore.shared.updateApp { $0.hostSwitchNotificationsEnabled = new }
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("System")
                InsetGroup {
                    InsetRow(
                        title: "Open System Settings",
                        subtitle: "Configure delivery, sound, and Focus filters per category."
                    ) {
                        iconBlock("gear", tint: .gray)
                    } trailing: {
                        Button("Open…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Updates pane

struct UpdatesPane: View {
    @ObservedObject private var checker = UpdateChecker.shared
    @State private var auto: Bool = SettingsStore.shared.app.autoUpdateEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: OptuneDesign.Spacing.xl) {
            PageHeader(
                "Updates",
                subtitle: "Optune checks the GitHub Releases page once per day for new builds. Click below to check now or open the changelog."
            )

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Status")
                InsetGroup {
                    InsetRow(
                        title: statusTitle,
                        subtitle: statusSubtitle
                    ) {
                        iconBlock(statusIcon, tint: statusTint)
                    } trailing: {
                        switch checker.status {
                        case .available:
                            Button("Download…") { checker.openLatestRelease() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        default:
                            Button("Check now") {
                                Task { await checker.checkNow() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if case .available(_, _, let notes) = checker.status, !notes.isEmpty {
                        GroupDivider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Release notes")
                                .font(OptuneDesign.Typography.body)
                            ScrollView {
                                Text(notes)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                            }
                            .frame(height: 160)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Preferences")
                InsetGroup {
                    InsetRow(
                        title: "Automatic checks",
                        subtitle: "Background check daily on launch."
                    ) {
                        iconBlock("clock.arrow.circlepath", tint: .blue)
                    } trailing: {
                        Toggle("", isOn: $auto)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: auto) { _, new in
                                SettingsStore.shared.updateApp { $0.autoUpdateEnabled = new }
                            }
                    }
                    GroupDivider()
                    InsetRow(
                        title: "Open Releases page",
                        subtitle: "Browse all builds on GitHub."
                    ) {
                        iconBlock("safari", tint: .indigo)
                    } trailing: {
                        Button("Open") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/Sanjays2402/optune/releases")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Text("Current build: \(checker.currentVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .onAppear {
            // Lazily kick a check the first time the pane is opened.
            if case .idle = checker.status {
                Task { await checker.checkNow() }
            }
        }
    }

    private var statusTitle: String {
        switch checker.status {
        case .idle:               return "Ready"
        case .checking:           return "Checking…"
        case .upToDate(let v):    return "You're on the latest build (\(v))"
        case .available(let v, _, _): return "Update available — \(v)"
        case .error:              return "Couldn't reach GitHub"
        }
    }
    private var statusSubtitle: String {
        switch checker.status {
        case .idle:               return "Tap “Check now” to look for a new build."
        case .checking:           return "Talking to api.github.com…"
        case .upToDate:           return "Optune will keep checking once a day."
        case .available:          return "Download the new DMG from the GitHub Release page."
        case .error(let msg):     return msg
        }
    }
    private var statusIcon: String {
        switch checker.status {
        case .idle:           return "arrow.down.circle"
        case .checking:       return "arrow.triangle.2.circlepath"
        case .upToDate:       return "checkmark.seal.fill"
        case .available:      return "sparkles"
        case .error:          return "exclamationmark.triangle.fill"
        }
    }
    private var statusTint: Color {
        switch checker.status {
        case .idle:           return .blue
        case .checking:       return .blue
        case .upToDate:       return .green
        case .available:      return .yellow
        case .error:          return .orange
        }
    }
}

// MARK: - Helpers

private struct UnavailableRow: View {
    let reason: String
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.14))
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not supported on this device")
                    .font(OptuneDesign.Typography.body)
                Text(reason)
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private func iconBlock(_ symbol: String, tint: Color) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(tint.opacity(0.14))
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
    }
    .frame(width: 22, height: 22)
}
