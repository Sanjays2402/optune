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
        case "hero":    return CGSize(width: 1600, height: 880)
        default:        return CGSize(width: 1240, height: 800)
        }
    }
}

private let options = Options()

@main
struct OptuneShowcase: App {
    init() {
        NSApplication.shared.appearance = NSAppearance(named: options.dark ? .darkAqua : .aqua)
        fputs("showcase: launched scene=\(options.scene)\n", stderr)
        // Headless path: render the SwiftUI tree straight to a PNG (no window server needed).
        if CommandLine.arguments.contains("--render"), let out = options.out {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    HeadlessRender.write(options: options, to: out)
                    exit(0)
                }
            }
        }
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
            fputs("showcase: window=\(view.window != nil)\n", stderr)
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

@MainActor
private enum HeadlessRender {
    static func write(options: Options, to path: String) {
        let view = SceneRoot(options: options)
            .frame(width: options.size.width, height: options.size.height)
            .environment(\.colorScheme, options.dark ? .dark : .light)
            .environment(\.optuneFlatGlass, true)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("showcase: render failed\n", stderr)
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        fputs("showcase: rendered \(path)\n", stderr)
    }
}

// MARK: - Backdrop

private struct Wallpaper<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        let dark = scheme == .dark
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: dark
                        ? [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.07, green: 0.04, blue: 0.20)]
                        : [Color(red: 0.80, green: 0.89, blue: 1.00), Color(red: 0.93, green: 0.85, blue: 1.00)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                // aurora
                Ellipse().fill(Color(red: 0.10, green: 0.62, blue: 1.00).opacity(dark ? 0.60 : 0.65))
                    .frame(width: w * 0.55, height: h * 0.55).blur(radius: 100).position(x: w * 0.10, y: h * 0.12)
                Ellipse().fill(Color(red: 0.55, green: 0.30, blue: 1.00).opacity(dark ? 0.65 : 0.55))
                    .frame(width: w * 0.50, height: h * 0.60).blur(radius: 110).position(x: w * 0.78, y: h * 0.18)
                Ellipse().fill(Color(red: 1.00, green: 0.25, blue: 0.62).opacity(dark ? 0.50 : 0.45))
                    .frame(width: w * 0.45, height: h * 0.45).blur(radius: 110).position(x: w * 0.28, y: h * 0.95)
                Ellipse().fill(Color(red: 0.10, green: 0.90, blue: 0.80).opacity(dark ? 0.40 : 0.50))
                    .frame(width: w * 0.40, height: h * 0.40).blur(radius: 110).position(x: w * 0.95, y: h * 0.92)
                content()
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hero

private struct Hero: View {
    var body: some View {
        Wallpaper {
            ZStack(alignment: .topLeading) {
                MockWindow(selected: "Devices", width: 1000, height: 690) { DevicesPane() }
                    .offset(x: 540, y: 96)
                MenuMock()
                    .frame(width: 380)
                    .offset(x: 70, y: 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    RingGauge(percent: 78, size: 40)
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
    var width: CGFloat = 1080
    var height: CGFloat = 700
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
        .frame(width: width, height: height)
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
                MockSlider(value: 1600, range: 200...8000)
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
                    MockToggle()
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
                MockToggle()
            }
            MockSlider(value: 25, range: 1...50)
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
                MockSlider(value: 20, range: 5...50)
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

// MARK: - Offscreen-safe controls (AppKit sliders/toggles can't be rendered headlessly)

private struct MockSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    var body: some View {
        GeometryReader { geo in
            let f = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.14)).frame(height: 5)
                Capsule().fill(Color.accentColor).frame(width: max(5, geo.size.width * f), height: 5)
                Circle().fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .offset(x: max(0, (geo.size.width - 18) * f))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
    }
}

private struct MockToggle: View {
    var on = true
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? Color.green : Color.primary.opacity(0.18)).frame(width: 38, height: 22)
            Circle().fill(Color.white).frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .padding(2)
        }
        .frame(width: 38, height: 22)
    }
}
