// OptuneShowcase — renders Optune's surfaces with synthetic telemetry for
// screenshots and marketing. Production users should run `OptuneApp`.
//
//   OptuneShowcase                          interactive hero window
//   OptuneShowcase --scene menu --dark --out menu.png
//                                           render one scene, save a PNG, quit
//
// Scenes: hero, menu, pointer, battery, buttons.

import SwiftUI
import AppKit
import OptuneCore
import OptuneUI

// MARK: - Launch arguments

private struct Options {
    var scene = "hero"
    var dark = true
    var out: String?

    init() {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--scene"), i + 1 < a.count { scene = a[i + 1] }
        if let i = a.firstIndex(of: "--out"), i + 1 < a.count { out = a[i + 1] }
        if a.contains("--light") { dark = false }
    }

    var size: CGSize {
        switch scene {
        case "menu":    return CGSize(width: 560, height: 700)
        case "hero":    return CGSize(width: 1480, height: 980)
        default:        return CGSize(width: 1240, height: 800)
        }
    }
}

private let options = Options()

@main
struct OptuneShowcase: App {
    init() {
        NSApplication.shared.appearance = NSAppearance(named: options.dark ? .darkAqua : .aqua)
    }

    var body: some Scene {
        WindowGroup("Optune — Showcase") {
            SceneRoot(options: options)
                .frame(width: options.size.width, height: options.size.height)
                .preferredColorScheme(options.dark ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

private struct SceneRoot: View {
    let options: Options

    var body: some View {
        Group {
            switch options.scene {
            case "menu":    Wallpaper { MenuMock().frame(width: 380) }
            case "pointer": Wallpaper { MockWindow(selected: "Pointer") { PointerPane() } }
            case "battery": Wallpaper { MockWindow(selected: "Devices") { DevicesPane() } }
            case "buttons": Wallpaper { MockWindow(selected: "Buttons") { ButtonsPane() } }
            default:        Hero()
            }
        }
        .background(WindowGrabber(out: options.out))
    }
}

// MARK: - Snapshot capture

private struct WindowGrabber: NSViewRepresentable {
    let out: String?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard let out else { return view }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = view.window else { exit(2) }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Snapshot.capture(window: window, to: out)
                exit(0)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private enum Snapshot {
    static func capture(window: NSWindow, to path: String) {
        // Preferred: the system compositor, so materials and glass render for real.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(window.windowNumber)", path]
        try? p.run()
        p.waitUntilExit()
        if let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int, size > 2_000 {
            return
        }
        // Fallback: draw the view hierarchy (no behind-window blur).
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Backdrop

private struct Wallpaper<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.05, green: 0.06, blue: 0.16), Color(red: 0.12, green: 0.05, blue: 0.24), Color(red: 0.03, green: 0.12, blue: 0.22)]
                    : [Color(red: 0.74, green: 0.82, blue: 0.99), Color(red: 0.90, green: 0.80, blue: 0.98), Color(red: 0.78, green: 0.92, blue: 0.97)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.purple.opacity(scheme == .dark ? 0.55 : 0.40)).frame(width: 520, height: 520)
                .blur(radius: 110).offset(x: -380, y: -220)
            Circle().fill(Color.blue.opacity(scheme == .dark ? 0.45 : 0.40)).frame(width: 460, height: 460)
                .blur(radius: 110).offset(x: 400, y: 280)
            Circle().fill(Color.pink.opacity(scheme == .dark ? 0.32 : 0.30)).frame(width: 340, height: 340)
                .blur(radius: 90).offset(x: -40, y: 360)
            content()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hero

private struct Hero: View {
    var body: some View {
        Wallpaper {
            VStack(spacing: 28) {
                HStack(alignment: .center, spacing: 16) {
                    BrandTile(size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optune")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("The open-source Logitech Options+ replacement for macOS — v\(OptuneCore.Optune.version)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Swift 6  ·  IOKit  ·  GPL-3.0")
                        Text("github.com/Sanjays2402/optune")
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 28) {
                    MenuMock().frame(width: 380)
                    VStack(spacing: 22) {
                        PointerCards()
                        BatteryCard()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                Spacer(minLength: 0)
            }
            .padding(48)
        }
    }
}

private struct BrandTile: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.linearGradient(colors: [.accentColor, .accentColor.opacity(0.55)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            Image(systemName: "computermouse.fill")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .accentColor.opacity(0.5), radius: size * 0.3, y: size * 0.1)
    }
}

// MARK: - Menu bar dropdown

private struct MenuMock: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BrandTile(size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Optune").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("v\(OptuneCore.Optune.version) · 1 device")
                        .font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.tint.opacity(0.16))
                        Image(systemName: "computermouse").font(.system(size: 18)).foregroundStyle(.tint)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MX Master 3S").font(OptuneDesign.Typography.header)
                        Text("Bluetooth Low Energy · 0xB034")
                            .font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    ConnectionChip(connected: true)
                }
                VStack(spacing: 10) {
                    FeatureRow(symbol: "battery.75", label: "Battery", secondary: "~3 days left · 1.4 %/hr") {
                        CapabilityPill(text: "78%", tone: .positive)
                    }
                    FeatureRow(symbol: "scope", label: "Pointer", secondary: "200–8000 dpi range") {
                        CapabilityPill(text: "1600 dpi", tone: .accent)
                    }
                    HStack(spacing: 6) {
                        ForEach([800, 1600, 3200, 4000], id: \.self) { v in
                            Text("\(v)")
                                .font(.system(size: 11, weight: .medium, design: .rounded)).monospacedDigit()
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Capsule().fill(v == 1600 ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.07)))
                                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(v == 1600 ? 0.45 : 0), lineWidth: 0.5))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 36)
                    FeatureRow(symbol: "wand.and.rays", symbolTint: .purple, label: "SmartShift", secondary: "Sensitivity 25") {
                        CapabilityPill(text: "On", tone: .positive)
                    }
                    FeatureRow(symbol: "rectangle.grid.2x2", symbolTint: .pink, label: "Buttons", secondary: "6 reprogrammable") {
                        CapabilityPill(text: "8", tone: .accent)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, 16).padding(.bottom, 12)

            Divider().opacity(0.4).padding(.horizontal, 16)

            VStack(spacing: 1) {
                menuRow("arrow.clockwise", "Refresh telemetry", "⌘R", hovered: false)
                menuRow("slider.horizontal.3", "Settings…", "⌘,", hovered: true)
                menuRow("arrow.up.right.square", "GitHub repository", nil, hovered: false)
                menuRow("power", "Quit Optune", "⌘Q", hovered: false)
            }
            .padding(8)
        }
        .background(LiquidGlassSurface())
        .clipShape(RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.40), radius: 30, y: 16)
    }

    private func menuRow(_ symbol: String, _ label: String, _ key: String?, hovered: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(.tint).frame(width: 18)
            Text(label).font(.system(size: 13, design: .rounded))
            Spacer()
            if let key { Text(key).font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(hovered ? Color.accentColor.opacity(0.18) : .clear))
    }
}

// MARK: - Settings window frame

private struct MockWindow<Content: View>: View {
    let selected: String
    @ViewBuilder let content: () -> Content

    private let panes: [(String, String, Color)] = [
        ("Devices", "computermouse", .accentColor), ("Pointer", "scope", .accentColor),
        ("Wheel", "circle.dotted.circle", .teal), ("Buttons", "rectangle.grid.2x2", .pink),
        ("Hosts", "rectangle.connected.to.line.below", .indigo), ("App Profiles", "app.badge.checkmark", .orange),
        ("Keyboard", "keyboard", .mint), ("Onboard", "internaldrive", .purple),
        ("Notifications", "bell.badge", .yellow), ("General", "gear", .gray),
        ("Updates", "arrow.down.circle", .blue), ("About", "info.circle", .accentColor),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 12, height: 12)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 12, height: 12)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 12, height: 12)
                }
                .padding(.leading, 16).padding(.top, 16).padding(.bottom, 14)
                HStack(spacing: 9) {
                    BrandTile(size: 24)
                    Text("Optune").font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(panes, id: \.0) { pane in
                        let on = pane.0 == selected
                        HStack(spacing: 9) {
                            Image(systemName: pane.1)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(on ? Color.white : Color.secondary)
                                .frame(width: 18)
                            Text(pane.0)
                                .font(.system(size: 13, weight: on ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(on ? Color.white : Color.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(on ? AnyShapeStyle(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.72)],
                                                                    startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(Color.clear)))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(on ? 0.30 : 0), lineWidth: 0.6))
                        .shadow(color: .accentColor.opacity(on ? 0.35 : 0), radius: 6, y: 2)
                    }
                }
                .padding(.horizontal, 8)
                Spacer()
                HStack(spacing: 6) {
                    StatusDot(tone: .green, pulse: false)
                    Text("1 device connected").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("v\(OptuneCore.Optune.version)").font(OptuneDesign.Typography.caption).foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .frame(width: 224)
            .background(.ultraThinMaterial)

            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { content() }
                        .padding(32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDisabled(true)
            }
        }
        .frame(width: 1080, height: 700)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
    }
}

private struct Header: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(OptuneDesign.Typography.title)
            Text(subtitle).font(OptuneDesign.Typography.body).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pointer

private struct PointerCards: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sensitivity").font(OptuneDesign.Typography.header)
                    Spacer()
                    Text("1600 dpi").font(OptuneDesign.Typography.value).foregroundStyle(.tint)
                }
                Slider(value: .constant(1600), in: 200...8000, step: 50)
                HStack {
                    Text("200").foregroundStyle(.tertiary)
                    Spacer()
                    Text("8000").foregroundStyle(.tertiary)
                }
                .font(OptuneDesign.Typography.caption)
            }
            .padding(20)
            .glassSurface(cornerRadius: OptuneDesign.Radius.card)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DPI stages").font(OptuneDesign.Typography.header)
                    Text("Saved values for the menu bar quick-switch, the “Cycle DPI Presets” action and the hotkey.")
                        .font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach([800, 1600, 3200, 4000], id: \.self) { v in
                        HStack(spacing: 4) {
                            Text("\(v)").monospacedDigit()
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .font(OptuneDesign.Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button("Add current DPI") {}.buttonStyle(.ghost)
                    Button("Reset to defaults") {}.buttonStyle(.ghost(tint: .secondary))
                    Spacer()
                    Text("⌃⌥D").font(OptuneDesign.Typography.mono).foregroundStyle(.secondary)
                    Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
            }
            .padding(20)
            .glassSurface(cornerRadius: OptuneDesign.Radius.card)
        }
    }
}

private struct PointerPane: View {
    var body: some View {
        Header(title: "Pointer", subtitle: "Tune sensitivity and the SmartShift wheel for your primary device.")
        PointerCards()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("SmartShift", systemImage: "wand.and.rays").font(OptuneDesign.Typography.header)
                Spacer()
                Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden()
            }
            Slider(value: .constant(25), in: 1...50, step: 1)
            Text("Lower values trip free-spin sooner. Higher values keep the wheel notched longer.")
                .font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .glassSurface(cornerRadius: OptuneDesign.Radius.card)
    }
}

// MARK: - Battery

private enum MockBattery {
    /// ~2.5 days of slow drain with a mid-way top-up, newest last.
    static let samples: [BatterySample] = {
        let now = Date()
        var out: [BatterySample] = []
        var pct = 96.0
        for i in 0..<120 {
            let t = now.addingTimeInterval(-Double(120 - i) * 1800)
            if i == 52 { pct = 58 }                 // short charge
            let charging = (52...54).contains(i)
            pct = charging ? min(100, pct + 12) : max(5, pct - 0.55 - Double(i % 5) * 0.06)
            out.append(BatterySample(timestamp: t, percent: Int(pct.rounded()), charging: charging))
        }
        return out
    }()
}

private struct BatteryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Battery trend").font(OptuneDesign.Typography.header)
                Spacer()
                HStack(spacing: 0) {
                    ForEach(["24 h", "7 d", "14 d"], id: \.self) { r in
                        Text(r).font(OptuneDesign.Typography.caption)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(r == "7 d" ? Color.accentColor.opacity(0.28) : .clear))
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            BatterySparkline(samples: MockBattery.samples, height: 90)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
            HStack(spacing: 28) {
                stat("~3 days", "Time left")
                stat("1.4%/hr", "Drain")
                stat("2 days ago", "Last charged")
                stat("3", "Charges")
                Spacer()
            }
            HStack(spacing: 10) {
                Text("Alert below").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                Slider(value: .constant(20), in: 5...50, step: 5)
                Text("20%").font(OptuneDesign.Typography.caption).monospacedDigit()
            }
        }
        .padding(20)
        .glassSurface(cornerRadius: OptuneDesign.Radius.card)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(OptuneDesign.Typography.value).monospacedDigit()
            Text(label).font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DevicesPane: View {
    var body: some View {
        Header(title: "Devices", subtitle: "Everything Optune can see and configure.")
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.tint.opacity(0.16))
                    Image(systemName: "computermouse").font(.system(size: 24)).foregroundStyle(.tint)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MX Master 3S").font(OptuneDesign.Typography.title2)
                    Text("Bluetooth Low Energy · serial 31A5D392")
                        .font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ConnectionChip(connected: true)
            }
            HStack(spacing: 10) {
                CapabilityPill(text: "78%", tone: .positive)
                CapabilityPill(text: "1600 dpi", tone: .accent)
                CapabilityPill(text: "SmartShift on", tone: .positive)
                CapabilityPill(text: "8 buttons", tone: .accent)
            }
        }
        .padding(20)
        .glassSurface(cornerRadius: OptuneDesign.Radius.card)
        BatteryCard()
    }
}

// MARK: - Buttons

private struct ButtonsPane: View {
    private let rows: [(String, String, String, String)] = [
        ("Middle Click", "cursorarrow.click", "0x0052", "Mission Control"),
        ("Back", "arrow.uturn.backward", "0x0053", "Back (⌘[)"),
        ("Forward", "arrow.uturn.forward", "0x0056", "Forward (⌘])"),
        ("Gesture Button", "hand.draw", "0x00C3", "Show Desktop"),
    ]

    var body: some View {
        Header(title: "Buttons", subtitle: "Remap any control — hold the gesture button and swipe for four more actions.")
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                if idx > 0 { Rectangle().fill(OptuneDesign.Layer.divider).frame(height: 0.5).padding(.leading, 52) }
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.accentColor.opacity(0.16))
                            Image(systemName: r.1).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.0).font(OptuneDesign.Typography.body)
                            Text("CID \(r.2)").font(OptuneDesign.Typography.mono).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        actionChip(r.3)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if r.0 == "Gesture Button" {
                        VStack(spacing: 6) {
                            ForEach([("up", "Mission Control"), ("down", "Show Desktop"), ("left", "Previous Space"), ("right", "Next Space")], id: \.0) { g in
                                HStack {
                                    Image(systemName: "arrow.\(g.0)").frame(width: 18).foregroundStyle(.secondary)
                                    Text("Swipe \(g.0.capitalized)").font(OptuneDesign.Typography.body)
                                    Spacer()
                                    actionChip(g.1)
                                }
                            }
                        }
                        .padding(.leading, 50).padding(.trailing, 14).padding(.bottom, 12)
                    }
                }
            }
        }
        .glassSurface(cornerRadius: OptuneDesign.Radius.group)
    }

    private func actionChip(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).font(OptuneDesign.Typography.caption)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 0.5))
    }
}
