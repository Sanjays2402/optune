import SwiftUI

/// A control that can be pointed at on the illustrated mouse.
public struct MouseHotspot: Identifiable, Hashable, Sendable {
    public enum Side: Sendable { case left, right }

    /// HID++ control ID.
    public let id: UInt16
    public let name: String
    /// Position on the illustration, 0…1 in both axes.
    public let point: CGPoint
    public let side: Side
    /// Vertical position of the callout, 0…1 of the view height.
    public let labelY: CGFloat

    public init(id: UInt16, name: String, point: CGPoint, side: Side, labelY: CGFloat) {
        self.id = id
        self.name = name
        self.point = point
        self.side = side
        self.labelY = labelY
    }

    /// Where the common controls sit on Optune's generic ergonomic-mouse drawing.
    public static let standard: [MouseHotspot] = [
        .init(id: 0x50, name: "Left click",     point: .init(x: 0.43, y: 0.20), side: .left,  labelY: 0.10),
        .init(id: 0x56, name: "Forward",        point: .init(x: 0.28, y: 0.42), side: .left,  labelY: 0.33),
        .init(id: 0x53, name: "Back",           point: .init(x: 0.27, y: 0.53), side: .left,  labelY: 0.52),
        .init(id: 0xC3, name: "Gesture button", point: .init(x: 0.235, y: 0.69), side: .left, labelY: 0.72),
        .init(id: 0x51, name: "Right click",    point: .init(x: 0.63, y: 0.20), side: .right, labelY: 0.10),
        .init(id: 0x52, name: "Wheel click",    point: .init(x: 0.525, y: 0.17), side: .right, labelY: 0.28),
        .init(id: 0xC4, name: "Top button",     point: .init(x: 0.525, y: 0.37), side: .right, labelY: 0.46),
        .init(id: 0xDA, name: "DPI button",     point: .init(x: 0.62, y: 0.50), side: .right, labelY: 0.64),
    ]
}

/// An illustrated mouse with a callout per control. Tapping a callout or its dot selects it.
///
/// The drawing is original, generic artwork — not a picture of any specific product.
public struct MouseMapView: View {
    public let hotspots: [MouseHotspot]
    /// What each control currently does, by CID (e.g. "Mission Control").
    public let actions: [UInt16: String]
    @Binding public var selected: UInt16?

    public init(hotspots: [MouseHotspot], actions: [UInt16: String], selected: Binding<UInt16?>) {
        self.hotspots = hotspots
        self.actions = actions
        self._selected = selected
    }

    public var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let art = h
            let ax = (w - art) / 2
            let chipW = max(120, min(190, ax - 12))

            ZStack(alignment: .topLeading) {
                MouseArt(selected: selected.flatMap { id in hotspots.first { $0.id == id } })
                    .frame(width: art, height: art)
                    .position(x: w / 2, y: h / 2)

                // Leader lines
                ForEach(hotspots) { hs in
                    let p = CGPoint(x: ax + hs.point.x * art, y: hs.point.y * art)
                    let edge = CGPoint(x: hs.side == .left ? 12 + chipW : w - 12 - chipW, y: hs.labelY * h)
                    Path { path in
                        path.move(to: edge)
                        path.addLine(to: p)
                    }
                    .stroke(selected == hs.id ? Color.accentColor : Color.primary.opacity(0.25),
                            style: StrokeStyle(lineWidth: selected == hs.id ? 1.6 : 1, lineCap: .round))
                }

                // Dots
                ForEach(hotspots) { hs in
                    let p = CGPoint(x: ax + hs.point.x * art, y: hs.point.y * art)
                    Circle()
                        .fill(selected == hs.id ? Color.accentColor : Color.white)
                        .frame(width: selected == hs.id ? 12 : 9, height: selected == hs.id ? 12 : 9)
                        .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1.5))
                        .shadow(color: Color.accentColor.opacity(selected == hs.id ? 0.6 : 0.25), radius: 5)
                        .position(p)
                        .onTapGesture { selected = hs.id }
                }

                // Callouts
                ForEach(hotspots) { hs in
                    let isOn = selected == hs.id
                    Button { selected = isOn ? nil : hs.id } label: {
                        VStack(alignment: hs.side == .left ? .trailing : .leading, spacing: 1) {
                            Text(hs.name)
                                .font(OptuneDesign.Typography.caption)
                                .foregroundStyle(.secondary)
                            Text(actions[hs.id] ?? "Default")
                                .font(OptuneDesign.Typography.value)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(width: chipW, alignment: hs.side == .left ? .trailing : .leading)
                        .glassSurface(cornerRadius: 12, tint: isOn ? .accentColor : nil, shadowRadius: isOn ? 10 : 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(isOn ? 0.8 : 0), lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                    .position(x: hs.side == .left ? 12 + chipW / 2 : w - 12 - chipW / 2, y: hs.labelY * h)
                }
            }
        }
    }
}

// MARK: - Artwork

/// Generic top-down ergonomic mouse, drawn from paths.
struct MouseArt: View {
    let selected: MouseHotspot?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                // soft contact shadow
                MouseBody().fill(Color.black.opacity(0.35)).blur(radius: s * 0.04).offset(y: s * 0.035)

                MouseBody()
                    .fill(LinearGradient(
                        colors: scheme == .dark
                            ? [Color(white: 0.34), Color(white: 0.15)]
                            : [Color(white: 0.52), Color(white: 0.28)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                MouseBody()
                    .fill(RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.20 : 0.28), .clear],
                                         center: UnitPoint(x: 0.45, y: 0.22), startRadius: 0, endRadius: s * 0.45))
                MouseBody()
                    .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), .white.opacity(0.22)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)

                // button seam + split
                Path { p in
                    p.move(to: pt(0.525, 0.07, s)); p.addLine(to: pt(0.525, 0.14, s))
                    p.move(to: pt(0.525, 0.27, s)); p.addLine(to: pt(0.525, 0.30, s))
                    p.move(to: pt(0.34, 0.33, s))
                    p.addQuadCurve(to: pt(0.74, 0.33, s), control: pt(0.54, 0.38, s))
                }
                .stroke(Color.black.opacity(0.45), lineWidth: 1.4)

                // scroll wheel
                RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.7), Color(white: 0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.055, height: s * 0.13)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.03, style: .continuous).strokeBorder(.black.opacity(0.5), lineWidth: 1))
                    .position(pt(0.525, 0.205, s))

                // thumb wheel, back/forward and gesture button on the thumb side
                Capsule().fill(Color(white: 0.22)).frame(width: s * 0.03, height: s * 0.09)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
                    .rotationEffect(.degrees(-8)).position(pt(0.305, 0.355, s))
                Capsule().fill(Color(white: 0.2)).frame(width: s * 0.075, height: s * 0.04)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
                    .rotationEffect(.degrees(-62)).position(pt(0.285, 0.43, s))
                Capsule().fill(Color(white: 0.2)).frame(width: s * 0.075, height: s * 0.04)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
                    .rotationEffect(.degrees(-70)).position(pt(0.272, 0.53, s))
                Ellipse().fill(Color(white: 0.2)).frame(width: s * 0.06, height: s * 0.07)
                    .overlay(Ellipse().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
                    .position(pt(0.235, 0.69, s))

                // top button + DPI button
                Capsule().fill(Color(white: 0.2)).frame(width: s * 0.07, height: s * 0.028)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
                    .position(pt(0.525, 0.37, s))
                Circle().fill(Color(white: 0.2)).frame(width: s * 0.034, height: s * 0.034)
                    .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
                    .position(pt(0.62, 0.50, s))

                // highlight on the selected control
                if let selected {
                    Circle()
                        .fill(Color.accentColor.opacity(0.28))
                        .frame(width: s * 0.11, height: s * 0.11)
                        .blur(radius: 6)
                        .position(pt(selected.point.x, selected.point.y, s))
                }
            }
        }
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
}

struct MouseBody: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(0.36, 0.10))
        path.addCurve(to: p(0.69, 0.10), control1: p(0.48, 0.05), control2: p(0.58, 0.05))
        path.addCurve(to: p(0.79, 0.40), control1: p(0.76, 0.10), control2: p(0.80, 0.25))
        path.addCurve(to: p(0.76, 0.78), control1: p(0.79, 0.55), control2: p(0.78, 0.68))
        path.addCurve(to: p(0.60, 0.93), control1: p(0.74, 0.88), control2: p(0.68, 0.93))
        path.addCurve(to: p(0.40, 0.93), control1: p(0.55, 0.95), control2: p(0.45, 0.95))
        path.addCurve(to: p(0.26, 0.84), control1: p(0.34, 0.92), control2: p(0.29, 0.90))
        path.addCurve(to: p(0.18, 0.62), control1: p(0.20, 0.80), control2: p(0.15, 0.70))
        path.addCurve(to: p(0.28, 0.45), control1: p(0.20, 0.54), control2: p(0.25, 0.50))
        path.addCurve(to: p(0.36, 0.10), control1: p(0.31, 0.30), control2: p(0.32, 0.18))
        path.closeSubpath()
        return path
    }
}
