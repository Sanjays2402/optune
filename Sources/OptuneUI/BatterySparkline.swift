import SwiftUI
import OptuneCore

/// Smooth battery trend line with a soft area fill, faint guides at 25/50/75 %
/// and a glowing marker on the latest reading.
public struct BatterySparkline: View {
    public let samples: [BatterySample]
    public let height: CGFloat
    /// Time window shown on the x-axis; nil spans the samples' own range.
    public var window: ClosedRange<Date>?

    public init(samples: [BatterySample], height: CGFloat, window: ClosedRange<Date>? = nil) {
        self.samples = samples
        self.height = height
        self.window = window
    }

    public var body: some View {
        Canvas { ctx, size in
            guard samples.count >= 2 else { return }
            let lo = window?.lowerBound ?? samples[0].timestamp
            let hi = window?.upperBound ?? samples[samples.count - 1].timestamp
            let span = max(hi.timeIntervalSince(lo), 1)
            let pts = samples.map { s in
                CGPoint(x: CGFloat(s.timestamp.timeIntervalSince(lo) / span) * size.width,
                        y: (1 - CGFloat(s.percent) / 100) * size.height)
            }

            for frac in [0.25, 0.5, 0.75] {
                var g = Path()
                let y = size.height * frac
                g.move(to: CGPoint(x: 0, y: y))
                g.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(g, with: .color(.primary.opacity(0.07)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }

            var line = Path()
            line.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                line.addQuadCurve(to: mid, control: pts[i - 1])
            }
            line.addLine(to: pts[pts.count - 1])

            var area = line
            area.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: size.height))
            area.addLine(to: CGPoint(x: pts[0].x, y: size.height))
            area.closeSubpath()
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(line, with: .linearGradient(
                Gradient(colors: [.green, .accentColor]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            let tip = pts[pts.count - 1]
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)),
                     with: .color(.accentColor.opacity(0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)),
                     with: .color(.white))
        }
        .frame(height: height)
    }
}
