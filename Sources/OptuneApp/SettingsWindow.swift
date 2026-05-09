import SwiftUI
import OptuneCore

struct SettingsWindow: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        TabView {
            DevicesTab()
                .tabItem { Label("Devices", systemImage: "computermouse") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 380)
        .padding(20)
    }
}

private struct DevicesTab: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Logitech HID interfaces")
                .font(.headline)
            if model.devices.isEmpty {
                ContentUnavailableView(
                    "No devices",
                    systemImage: "computermouse.fill",
                    description: Text("Pair a Logitech device or plug in a Bolt receiver.")
                )
            } else {
                Table(model.devices) {
                    TableColumn("Product") { device in
                        Text(device.displayName).font(.system(size: 12))
                    }
                    TableColumn("PID") { device in
                        Text(String(format: "0x%04X", device.productID))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    TableColumn("Transport") { device in
                        Text(device.transport ?? "—").font(.system(size: 12))
                    }
                    TableColumn("Usage") { device in
                        Text(String(format: "0x%04X/0x%04X", device.usagePage, device.usage))
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
            }
            HStack {
                Spacer()
                Button("Refresh") { model.refresh() }
            }
        }
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Optune")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("v\(OptuneCore.Optune.version)")
                .foregroundStyle(.secondary)
            Text("Configure Logitech devices on macOS — Logitech Options+ alternative.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Link("github.com/Sanjays2402/optune",
                 destination: URL(string: OptuneCore.Optune.projectURL)!)
            Spacer()
        }
        .padding()
    }
}
