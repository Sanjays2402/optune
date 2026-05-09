import Combine
import Foundation
import OptuneCore

@MainActor
final class DeviceModel: ObservableObject {
    @Published private(set) var devices: [LogitechDevice] = []
    @Published private(set) var lastRefresh: Date = .distantPast

    private var refreshTask: Task<Void, Never>?

    init() {
        refresh()
        // Re-poll every 4s. A real implementation would subscribe to IOKit notifications,
        // but polling is fine for the MVP and dodges sandbox surprises during development.
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.refresh()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() {
        let next = HIDEnumerator.logitechDevices()
        self.devices = next
        self.lastRefresh = Date()
    }

    var recognizedDevices: [LogitechDevice] {
        devices.filter { DeviceRegistry.descriptor(for: $0) != nil }
    }

    var recognizedCount: Int {
        // De-duplicate multi-interface entries (Bolt receiver + paired mouse appear twice).
        Set(recognizedDevices.compactMap { DeviceRegistry.descriptor(for: $0)?.codename }).count
    }

    var primaryDevice: LogitechDevice? {
        recognizedDevices.first(where: { $0.isMXMaster3S }) ?? recognizedDevices.first
    }

    var primaryDescriptor: DeviceDescriptor? {
        guard let primaryDevice else { return nil }
        return DeviceRegistry.descriptor(for: primaryDevice)
    }
}
