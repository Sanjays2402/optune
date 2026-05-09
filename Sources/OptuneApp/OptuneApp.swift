import SwiftUI
import OptuneCore

@main
struct OptuneApp: App {
    @StateObject private var deviceModel = DeviceModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(deviceModel)
                .frame(width: 380)
        } label: {
            MenuBarLabel()
                .environmentObject(deviceModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow()
                .environmentObject(deviceModel)
        }
    }
}

/// Menu-bar label with a battery-aware mouse icon and inline percent text.
private struct MenuBarLabel: View {
    @EnvironmentObject private var model: DeviceModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
            if let label = trailingLabel {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    private var iconName: String {
        if case .ok(_, let charging, _) = model.telemetry.battery, charging {
            return "computermouse.fill"
        }
        return "computermouse.fill"
    }

    private var iconTint: Color {
        guard case .ok(let percent, _, _) = model.telemetry.battery else { return .primary }
        if percent <= 15 { return .red }
        if percent <= 30 { return .orange }
        return .primary
    }

    private var trailingLabel: String? {
        if case .ok(let percent, let charging, _) = model.telemetry.battery {
            return charging ? "⚡\(Int(percent))%" : "\(Int(percent))%"
        }
        if model.recognizedCount > 0 {
            return "\(model.recognizedCount)"
        }
        return nil
    }
}
