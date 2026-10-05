import SwiftUI
import OptuneCore
import OptuneUI

/// Battery trend chart (24 h / 7 d / 14 d), drain + time-remaining estimates,
/// and a per-device low-battery threshold.
struct BatteryInsightsCard: View {
    let device: LogitechDevice

    private enum Range: String, CaseIterable, Identifiable {
        case day = "24 h", week = "7 d", twoWeeks = "14 d"
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .day: 24 * 3600
            case .week: 7 * 24 * 3600
            case .twoWeeks: 14 * 24 * 3600
            }
        }
    }

    @State private var range: Range = .day
    @State private var thresholdDraft: Double = 20
    @State private var loaded = false

    var body: some View {
        let all = SettingsStore.shared.batteryHistory(for: device)
        let now = Date()
        let from = now.addingTimeInterval(-range.seconds)
        let visible = all.filter { $0.timestamp >= from }
        let insights = BatteryInsights.analyze(all)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Battery trend")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                .controlSize(.small)
            }

            if visible.count >= 2 {
                BatterySparkline(samples: visible, height: 48, window: from...now)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            } else {
                Text("Collecting data — the chart fills in as Optune polls this device.")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            }

            HStack(spacing: 16) {
                stat("Time left",
                     insights.hoursRemaining.map(BatteryInsights.formatRemaining(hours:)) ?? "—")
                stat("Drain",
                     insights.drainPerHour.map { String(format: "%.1f%%/hr", $0) } ?? "—")
                stat("Last charged",
                     insights.lastChargedAt.map { $0.formatted(.relative(presentation: .named)) } ?? "—")
                stat("Charges", "\(insights.chargeSessions)")
            }

            HStack {
                Text("Alert below")
                    .font(OptuneDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $thresholdDraft, in: 5...50, step: 5) { editing in
                    if !editing { saveThreshold() }
                }
                Text("\(Int(thresholdDraft))%")
                    .font(OptuneDesign.Typography.caption)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .onAppear {
            guard !loaded else { return }
            thresholdDraft = Double(SettingsStore.shared.lowBatteryThreshold(for: device))
            loaded = true
        }
    }

    private func saveThreshold() {
        let value = Int(thresholdDraft)
        SettingsStore.shared.update(for: device) { $0.lowBatteryThreshold = value }
        OptuneNotifications.shared.resetLowBatteryLatch()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(OptuneDesign.Typography.value).monospacedDigit()
            Text(label).font(OptuneDesign.Typography.caption).foregroundStyle(.secondary)
        }
    }
}
