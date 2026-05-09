// OptuneShowcase — a standalone window that renders the same UI surfaces as
// the OptuneApp menu bar dropdown, used purely for screenshots/marketing.
// Production users should run `OptuneApp`, not this.

import SwiftUI
import OptuneCore

@main
struct OptuneShowcase: App {
    @StateObject private var model = ShowcaseModel()

    var body: some Scene {
        WindowGroup("Optune — Showcase") {
            ShowcaseView()
                .environmentObject(model)
                .frame(width: 880, height: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

@MainActor
final class ShowcaseModel: ObservableObject {
    @Published var devices: [LogitechDevice] = HIDEnumerator.logitechDevices()

    /// Synthesize a recognised device when none are attached, so the showcase
    /// always demonstrates the populated UI state.
    var primaryDevice: LogitechDevice {
        devices.first(where: { DeviceRegistry.descriptor(for: $0) != nil })
            ?? LogitechDevice(
                productID: 0xB034,
                productName: "MX Master 3S",
                manufacturer: "Logitech",
                serialNumber: "31A5D392",
                transport: "Bluetooth Low Energy",
                usagePage: HIDPP.usagePageVendorLong,
                usage: 0x0001
            )
    }

    var primaryDescriptor: DeviceDescriptor {
        DeviceRegistry.descriptor(for: primaryDevice) ?? DeviceRegistry.mxMaster3S
    }

    var recognizedCount: Int {
        max(1, Set(devices.compactMap { DeviceRegistry.descriptor(for: $0)?.codename }).count)
    }
}

struct ShowcaseView: View {
    @EnvironmentObject private var model: ShowcaseModel

    var body: some View {
        ZStack {
            // Wallpaper-ish backdrop so Liquid Glass actually has something to refract.
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.04, blue: 0.18),
                    Color(red: 0.02, green: 0.10, blue: 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle ambient orbs to give the glass something to bend.
            Circle()
                .fill(.purple.opacity(0.45))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -260, y: -160)
            Circle()
                .fill(.blue.opacity(0.40))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 260, y: 200)
            Circle()
                .fill(.pink.opacity(0.25))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: 0, y: 200)

            HStack(alignment: .top, spacing: 40) {
                BrandPanel()
                MenuPanel(
                    device: model.primaryDevice,
                    descriptor: model.primaryDescriptor,
                    recognizedCount: model.recognizedCount
                )
                .frame(width: 380)
            }
            .padding(40)
        }
    }
}

private struct BrandPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.linearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                .shadow(color: .accentColor.opacity(0.4), radius: 18, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Optune")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("v\(OptuneCore.Optune.version) · Native macOS")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Text("Configure Logitech devices on macOS.")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            Text("Open-source. No account. No telemetry. No background AI service. Just a menu bar app and a CLI.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)
                .frame(maxWidth: 360, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                FeatureBullet(symbol: "swift", text: "Swift 6 + SwiftUI Liquid Glass")
                FeatureBullet(symbol: "cpu", text: "IOKit HIDManager — no kernel extensions")
                FeatureBullet(symbol: "terminal", text: "`optune` CLI ships alongside the app")
                FeatureBullet(symbol: "lock.shield", text: "GPL-3.0, no telemetry, no account")
            }
            .padding(.top, 4)

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.white.opacity(0.7))
                Text("github.com/Sanjays2402/optune")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FeatureBullet: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

private struct MenuPanel: View {
    let device: LogitechDevice
    let descriptor: DeviceDescriptor
    let recognizedCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HeaderCard(recognizedCount: recognizedCount)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            DeviceCard(device: device, descriptor: descriptor)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.4).padding(.horizontal, 16)

            VStack(spacing: 2) {
                MenuRow(symbol: "arrow.clockwise",      label: "Refresh devices",       isHovered: false)
                MenuRow(symbol: "arrow.up.right.square", label: "Open project on GitHub", isHovered: true)
                MenuRow(symbol: "power",                 label: "Quit Optune",           isHovered: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(LiquidGlass())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }
}

private struct HeaderCard: View {
    let recognizedCount: Int

    var body: some View {
        HStack(spacing: 12) {
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
                Text("v\(OptuneCore.Optune.version) · \(recognizedCount) device\(recognizedCount == 1 ? "" : "s")")
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
                StatusPill(text: "Connected")
            }

            VStack(alignment: .leading, spacing: 8) {
                CapabilityRow(symbol: "battery.100",     label: "Battery",       value: "—  pending HID++")
                CapabilityRow(symbol: "scope",           label: "DPI",           value: "—  pending HID++")
                CapabilityRow(symbol: "wand.and.rays",   label: "SmartShift",    value: "—  pending HID++")
                CapabilityRow(symbol: "scroll.fill",     label: "Smooth scroll", value: descriptor.supportsSmoothScroll ? "Available" : "Not supported")
            }
        }
        .padding(14)
        .background(GlassCard())
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
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(.green).frame(width: 6, height: 6)
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
    let symbol: String
    let label: String
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(label).font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }
}

private struct LiquidGlass: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GlassCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}
