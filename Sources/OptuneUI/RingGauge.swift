import SwiftUI

/// Circular battery gauge: gradient arc, bold percentage, bolt while charging.
public struct RingGauge: View {
    public let percent: Int
    public let charging: Bool
    public let size: CGFloat

    public init(percent: Int, charging: Bool = false, size: CGFloat = 44) {
        self.percent = percent
        self.charging = charging
        self.size = size
    }

    private var tint: Color {
        if charging { return .green }
        if percent <= 15 { return .red }
        if percent <= 30 { return .orange }
        return .green
    }

    public var body: some View {
        let line = max(3, size * 0.1)
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: line)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 1), 100)) / 100)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * Double(percent) / 100)),
                    style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: size * 0.08)
            VStack(spacing: -1) {
                if charging {
                    Image(systemName: "bolt.fill").font(.system(size: size * 0.2)).foregroundStyle(tint)
                }
                Text("\(percent)")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
        .padding(line / 2)
    }
}
