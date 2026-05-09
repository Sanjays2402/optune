// OptuneShowcase — standalone window that renders the v0.3 surfaces
// (menu dropdown, pointer pane, buttons pane, about pane) with synthetic
// telemetry, used purely for screenshots / marketing. Production users
// should run `OptuneApp`, not this.

import SwiftUI
import OptuneCore
import OptuneUI

@main
struct OptuneShowcase: App {
    var body: some Scene {
        WindowGroup("Optune — Showcase") {
            ShowcaseHero()
                .frame(width: 1480, height: 980)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - Synthetic telemetry

private enum Mock {
    static let device = LogitechDevice(
        productID: 0xB034,
        productName: "MX Master 3S",
        manufacturer: "Logitech",
        serialNumber: "31A5D392",
        transport: "Bluetooth Low Energy",
        usagePage: HIDPP.usagePageVendorLong,
        usage: 0x0001
    )

    static let descriptor = DeviceRegistry.mxMaster3S

    static let telemetry: ShowTelemetry = {
        var t = ShowTelemetry()
        t.battery = .ok(percent: 78, charging: false, externalPower: false)
        t.dpi = .ok(current: 4000, min: 200, max: 8000)
        t.smartShift = .ok(enabled: true, threshold: 25)
        t.buttons = .ok(controls: [
            .init(index: 0, cid: 0x50, name: "Left Click", isReprog: false, position: 1),
            .init(index: 1, cid: 0x51, name: "Right Click", isReprog: false, position: 2),
            .init(index: 2, cid: 0x52, name: "Middle Click", isReprog: true, position: 3),
            .init(index: 3, cid: 0x53, name: "Back", isReprog: true, position: 4),
            .init(index: 4, cid: 0x56, name: "Forward", isReprog: true, position: 5),
            .init(index: 5, cid: 0xC4, name: "Smart Shift", isReprog: true, position: 6),
            .init(index: 6, cid: 0xC3, name: "Gesture Button", isReprog: true, position: 7),
            .init(index: 7, cid: 0xD7, name: "DPI Switch", isReprog: true, position: 8),
        ])
        return t
    }()
}

private struct ShowTelemetry: Equatable {
    enum Battery: Equatable {
        case ok(percent: UInt8, charging: Bool, externalPower: Bool)
    }
    enum DPI: Equatable {
        case ok(current: Int, min: Int, max: Int)
    }
    enum SmartShift: Equatable {
        case ok(enabled: Bool, threshold: UInt8)
    }
    struct ButtonControl: Identifiable, Equatable {
        var id: UInt8 { index }
        let index: UInt8
        let cid: UInt16
        let name: String
        let isReprog: Bool
        let position: UInt8
    }
    enum Buttons: Equatable {
        case ok(controls: [ButtonControl])
    }

    var battery: Battery = .ok(percent: 78, charging: false, externalPower: false)
    var dpi: DPI = .ok(current: 4000, min: 200, max: 8000)
    var smartShift: SmartShift = .ok(enabled: true, threshold: 25)
    var buttons: Buttons = .ok(controls: [])
}

// MARK: - Hero composition

struct ShowcaseHero: View {
    var body: some View {
        ZStack {
            // Macos-26 ish wallpaper backdrop — gives Liquid Glass something to refract
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.13),
                    Color(red: 0.10, green: 0.04, blue: 0.20),
                    Color(red: 0.02, green: 0.10, blue: 0.18),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient orbs — visible refraction targets behind glass.
            Circle().fill(.purple.opacity(0.55)).frame(width: 480, height: 480).blur(radius: 110).offset(x: -360, y: -200)
            Circle().fill(.blue.opacity(0.45)).frame(width: 420, height: 420).blur(radius: 110).offset(x: 380, y: 260)
            Circle().fill(.pink.opacity(0.30)).frame(width: 320, height: 320).blur(radius: 90).offset(x: -50, y: 380)

            VStack(spacing: 28) {
                BrandHeader()
                HStack(alignment: .top, spacing: 28) {
                    MenuShowcase().frame(width: 380)
                    VStack(spacing: 24) {
                        PointerShowcase()
                        ButtonsShowcase()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                Spacer(minLength: 0)
            }
            .padding(48)
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)
            .shadow(color: .accentColor.opacity(0.5), radius: 22, y: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text("Optune")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Native Logitech Options+ replacement for macOS 26 — v\(OptuneCore.Optune.version)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Swift 6  ·  IOKit  ·  GPL-3.0")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Text("github.com/Sanjays2402/optune")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Menu dropdown showcase (mirrors MenuContent)

private struct MenuShowcase: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.linearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .accentColor.opacity(0.25), radius: 8, y: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Optune").font(OptuneDesign.Typography.title)
                    Text("v\(OptuneCore.Optune.version) · 1 device")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            // Device card
            ShowcaseDeviceCard(telemetry: Mock.telemetry)
                .padding(.horizontal, 16).padding(.bottom, 12)

            Divider().opacity(0.4).padding(.horizontal, 16)

            VStack(spacing: 2) {
                showRow("arrow.clockwise",      "Refresh telemetry",     hovered: false)
                showRow("slider.horizontal.3",  "Open Optune Settings…", hovered: true)
                showRow("arrow.up.right.square","Open project on GitHub",hovered: false)
                showRow("power",                "Quit Optune",           hovered: false)
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
        .background(LiquidGlassSurface())
        .clipShape(RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }

    @ViewBuilder
    private func showRow(_ symbol: String, _ label: String, hovered: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)
            Text(label).font(.system(size: 13, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovered ? Color.accentColor.opacity(0.16) : Color.clear)
        )
    }
}

private struct ShowcaseDeviceCard: View {
    let telemetry: ShowTelemetry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
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
                    Text("MX Master 3S").font(OptuneDesign.Typography.header)
                    HStack(spacing: 6) {
                        Text("0xB034").font(OptuneDesign.Typography.mono).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.secondary)
                        Text("Bluetooth").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    StatusDot(tone: .green, pulse: true)
                    Text("Connected")
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
            }

            VStack(spacing: 8) {
                FeatureRow(symbol: "battery.75", symbolTint: .accentColor,
                           label: "Battery", secondary: "Bluetooth · ~3 days") {
                    CapabilityPill(text: "78%", tone: .accent)
                }
                FeatureRow(symbol: "scope", symbolTint: .accentColor,
                           label: "DPI", secondary: "Range 200 … 8000") {
                    CapabilityPill(text: "4000", tone: .accent)
                }
                FeatureRow(symbol: "wand.and.rays", symbolTint: .purple,
                           label: "SmartShift", secondary: "Sensitivity 25") {
                    CapabilityPill(text: "On", tone: .positive)
                }
                FeatureRow(symbol: "rectangle.grid.2x2", symbolTint: .pink,
                           label: "Buttons", secondary: "6 reprogrammable") {
                    CapabilityPill(text: "8", tone: .accent)
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Pointer pane showcase

private struct PointerShowcase: View {
    @State private var dpi: Double = 4000
    @State private var threshold: Double = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Pointer · DPI", systemImage: "scope")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                CapabilityPill(text: "\(Int(dpi)) dpi", tone: .accent)
            }
            Slider(value: $dpi, in: 200...8000, step: 50)
            HStack {
                Text("200").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Drag to apply — clamped to firmware range")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("8000").font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
            }

            Divider().opacity(0.3)

            HStack {
                Label("SmartShift wheel", systemImage: "wand.and.rays")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden()
            }
            HStack(spacing: 12) {
                Slider(value: $threshold, in: 1...50, step: 1)
                CapabilityPill(text: "\(Int(threshold))", tone: .accent)
            }
            Text("Lower values trip freespin sooner. Higher values keep the wheel notched longer.")
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }
}

// MARK: - Buttons pane showcase

private struct ButtonsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Reprogrammable buttons", systemImage: "rectangle.grid.2x2")
                    .font(OptuneDesign.Typography.header)
                Spacer()
                CapabilityPill(text: "0x1B04", tone: .accent)
            }
            VStack(spacing: 6) {
                ForEach([
                    ("Middle Click",    0x52, true,  "cursorarrow.click"),
                    ("Back",            0x53, true,  "arrow.uturn.backward"),
                    ("Forward",         0x56, true,  "arrow.uturn.forward"),
                    ("Smart Shift",     0xC4, true,  "wand.and.rays"),
                    ("Gesture Button",  0xC3, true,  "hand.draw"),
                    ("DPI Switch",      0xD7, true,  "scope"),
                ], id: \.1) { tuple in
                    let (name, cid, reprog, sym) = tuple
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(reprog ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.14))
                            Image(systemName: sym)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(reprog ? Color.accentColor : Color.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name).font(OptuneDesign.Typography.body)
                            Text(String(format: "CID 0x%04X", cid))
                                .font(OptuneDesign.Typography.mono)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        CapabilityPill(text: "Reprog", tone: .accent)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .glassCard()
    }
}
