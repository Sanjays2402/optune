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

                // Leader lines — short horizontal run out of the callout, then straight to the dot.
                ForEach(hotspots) { hs in
                    let p = CGPoint(x: ax + hs.point.x * art, y: hs.point.y * art)
                    let edge = CGPoint(x: hs.side == .left ? 12 + chipW : w - 12 - chipW, y: hs.labelY * h)
                    let elbow = CGPoint(x: edge.x + (hs.side == .left ? 26 : -26), y: edge.y)
                    let on = selected == hs.id
                    Path { path in
                        path.move(to: edge)
                        path.addLine(to: elbow)
                        path.addLine(to: p)
                    }
                    .stroke(on ? Color.accentColor : Color.primary.opacity(0.28),
                            style: StrokeStyle(lineWidth: on ? 1.6 : 1, lineCap: .round, lineJoin: .round))
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

/// A raised, bevelled control cap.
private struct Key<S: Shape>: View {
    let shape: S
    var body: some View {
        // wall under the cap so it stands proud of the shell
        shape.fill(Color.black.opacity(0.75)).offset(x: 0.8, y: 2.2)
            .overlay(content)
    }

    private var content: some View {
        shape
            .fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.03)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.9))
            .shadow(color: .black.opacity(0.55), radius: 1.6, y: 1.2)
    }
}

/// Generic top-down ergonomic mouse, drawn from paths with layered shading.
struct MouseArt: View {
    let selected: MouseHotspot?
    @Environment(\.colorScheme) private var scheme
    private let dbg = Int(ProcessInfo.processInfo.environment["OPTUNE_MOUSE_DEBUG"] ?? "") ?? 0   // TEMP

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            let dark = scheme == .dark
            ZStack {
                // Ground shadow: a tight contact shadow plus a wide ambient one.
                if dbg & 8 == 0 { MouseBody().fill(Color.black.opacity(dark ? 0.26 : 0.20)).blur(radius: s * 0.014).offset(x: s * 0.016, y: s * 0.05)
                MouseBody().fill(Color.black.opacity(dark ? 0.45 : 0.28)).blur(radius: s * 0.005).offset(x: s * 0.007, y: s * 0.03) }

                // Side wall: stacked copies of the outline, stepping down and to the right, so the
                // shell has visible thickness. Lit near the top edge, dark toward the desk.
                if dbg & 1 == 0 { ForEach((1...22).reversed(), id: \.self) { i in
                    let t = Double(i) / 22
                    MouseBody()
                        .fill(Color(white: (dark ? 0.34 : 0.46) * (1 - 0.90 * t)))
                        .offset(x: s * 0.0012 * CGFloat(i), y: s * 0.0050 * CGFloat(i))
                } }

                // Shell: a dome — bright crest up and to the left, falling off to the lower right.
                MouseBody()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(white: dark ? 0.46 : 0.62), location: 0.0),
                            .init(color: Color(white: dark ? 0.27 : 0.42), location: 0.38),
                            .init(color: Color(white: dark ? 0.12 : 0.22), location: 0.80),
                            .init(color: Color(white: dark ? 0.06 : 0.14), location: 1.0),
                        ],
                        startPoint: UnitPoint(x: 0.15, y: 0.05), endPoint: UnitPoint(x: 0.95, y: 0.98)))

                // Raised panel for the left/right click buttons
                Path { p in
                    p.move(to: pt(0, 0, s)); p.addLine(to: pt(1, 0, s)); p.addLine(to: pt(1, 0.33, s))
                    p.addLine(to: pt(0.745, 0.33, s))
                    p.addQuadCurve(to: pt(0.335, 0.33, s), control: pt(0.54, 0.385, s))
                    p.addLine(to: pt(0, 0.33, s)); p.closeSubpath()
                }
                .fill(Color.white.opacity(dark ? 0.07 : 0.10))
                .mask(MouseBody())

                // Inner shadow around the edge gives the shell volume.
                if dbg & 16 == 0 { MouseBody()
                    .stroke(Color.black.opacity(0.55), lineWidth: s * 0.07)
                    .blur(radius: s * 0.028)
                    .clipShape(MouseBody()) }

                // Soft top light and a diagonal specular streak.
                MouseBody()
                    .fill(RadialGradient(colors: [.white.opacity(dark ? 0.26 : 0.34), .clear],
                                         center: UnitPoint(x: 0.42, y: 0.20), startRadius: 0, endRadius: s * 0.46))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.13), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.10, height: s * 1.2)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -s * 0.08, y: -s * 0.02)
                    .mask(MouseBody())

                // Softbox reflection on the dome
                if dbg & 2 == 0 { RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(dark ? 0.22 : 0.30), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.26, height: s * 0.34)
                    .rotationEffect(.degrees(-14))
                    .blur(radius: s * 0.012)
                    .position(pt(0.60, 0.26, s))
                    .mask(MouseBody()) }
                // A thin bright edge where the dome meets the wall, lower right.
                if dbg & 4 == 0 { MouseBody()
                    .stroke(LinearGradient(colors: [.clear, .white.opacity(0.0), .white.opacity(0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .blur(radius: 0.6) }

                // Rim light
                MouseBody()
                    .stroke(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.04), .white.opacity(0.28)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)

                // Button seams, embossed: a dark groove with a light edge just below it.
                seams(s, color: .black.opacity(0.6), dy: 0)
                seams(s, color: .white.opacity(0.18), dy: 1.2)

                // Rubber grip texture on the thumb rest.
                Canvas { ctx, size in
                    let step = size.width * 0.022
                    var y = size.height * 0.52
                    var row = 0
                    while y < size.height * 0.86 {
                        var x = size.width * 0.16 + (row % 2 == 0 ? 0 : step / 2)
                        while x < size.width * 0.31 {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                                     with: .color(.white.opacity(0.16)))
                            x += step
                        }
                        y += step
                        row += 1
                    }
                }
                .mask(
                    Ellipse().frame(width: s * 0.13, height: s * 0.32).rotationEffect(.degrees(12))
                        .position(pt(0.235, 0.69, s))
                )

                // Scroll wheel: dark well, metallic ridged wheel.
                RoundedRectangle(cornerRadius: s * 0.034, style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: s * 0.072, height: s * 0.155)
                    .position(pt(0.525, 0.205, s))
                RoundedRectangle(cornerRadius: s * 0.028, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.82), Color(white: 0.30)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.054, height: s * 0.138)
                    .overlay(
                        VStack(spacing: s * 0.0075) {
                            ForEach(0..<13, id: \.self) { _ in
                                Rectangle().fill(Color.black.opacity(0.32)).frame(height: 0.9)
                            }
                        }
                        .padding(.vertical, s * 0.01)
                        .clipShape(RoundedRectangle(cornerRadius: s * 0.028, style: .continuous))
                    )
                    .position(pt(0.525, 0.205, s))

                // Side wheel, back / forward and gesture button on the thumb side.
                Key(shape: Capsule()).frame(width: s * 0.03, height: s * 0.09)
                    .rotationEffect(.degrees(-8)).position(pt(0.305, 0.355, s))
                Key(shape: Capsule()).frame(width: s * 0.078, height: s * 0.042)
                    .rotationEffect(.degrees(-62)).position(pt(0.285, 0.43, s))
                Key(shape: Capsule()).frame(width: s * 0.078, height: s * 0.042)
                    .rotationEffect(.degrees(-70)).position(pt(0.272, 0.53, s))
                Key(shape: Ellipse()).frame(width: s * 0.064, height: s * 0.074)
                    .overlay(Ellipse().strokeBorder(.white.opacity(0.18), lineWidth: 0.8).padding(s * 0.011))
                    .position(pt(0.235, 0.69, s))

                // Top button and DPI button.
                Key(shape: Capsule()).frame(width: s * 0.072, height: s * 0.03).position(pt(0.525, 0.37, s))
                Key(shape: Circle()).frame(width: s * 0.036, height: s * 0.036).position(pt(0.62, 0.50, s))

                // Glow on the selected control.
                if let selected {
                    Circle()
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: s * 0.12, height: s * 0.12)
                        .blur(radius: 7)
                        .position(pt(selected.point.x, selected.point.y, s))
                }
            }
        }
    }

    private func seams(_ s: CGFloat, color: Color, dy: CGFloat) -> some View {
        Path { p in
            p.move(to: pt(0.525, 0.065, s)); p.addLine(to: pt(0.525, 0.13, s))
            p.move(to: pt(0.525, 0.28, s)); p.addLine(to: pt(0.525, 0.31, s))
            p.move(to: pt(0.335, 0.33, s))
            p.addQuadCurve(to: pt(0.745, 0.33, s), control: pt(0.54, 0.385, s))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        .offset(y: dy)
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
