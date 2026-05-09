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
            HStack(spacing: 4) {
                Image(systemName: "computermouse.fill")
                if deviceModel.recognizedCount > 0 {
                    Text("\(deviceModel.recognizedCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow()
                .environmentObject(deviceModel)
        }
    }
}
