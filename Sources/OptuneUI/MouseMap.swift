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

    /// Hotspots for a drawing style. The positions match the artwork in `MouseLayout`.
    public static func layout(for shape: MouseShape) -> [MouseHotspot] {
        switch shape {
        case .ergonomic: return standard
        case .compact: return [
            .init(id: 0x50, name: "Left click",     point: .init(x: 0.42, y: 0.25), side: .left,  labelY: 0.12),
            .init(id: 0x56, name: "Forward",        point: .init(x: 0.29, y: 0.50), side: .left,  labelY: 0.40),
            .init(id: 0x53, name: "Back",           point: .init(x: 0.29, y: 0.585), side: .left, labelY: 0.57),
            .init(id: 0xC3, name: "Gesture button", point: .init(x: 0.30, y: 0.68), side: .left,  labelY: 0.74),
            .init(id: 0x51, name: "Right click",    point: .init(x: 0.58, y: 0.25), side: .right, labelY: 0.12),
            .init(id: 0x52, name: "Wheel click",    point: .init(x: 0.50, y: 0.215), side: .right, labelY: 0.30),
            .init(id: 0xC4, name: "Top button",     point: .init(x: 0.50, y: 0.43), side: .right, labelY: 0.48),
        ]
        case .vertical: return [
            .init(id: 0x50, name: "Left click",     point: .init(x: 0.45, y: 0.20), side: .left,  labelY: 0.12),
            .init(id: 0x56, name: "Forward",        point: .init(x: 0.335, y: 0.40), side: .left, labelY: 0.38),
            .init(id: 0x53, name: "Back",           point: .init(x: 0.33, y: 0.50), side: .left,  labelY: 0.56),
            .init(id: 0x51, name: "Right click",    point: .init(x: 0.62, y: 0.20), side: .right, labelY: 0.12),
            .init(id: 0x52, name: "Wheel click",    point: .init(x: 0.53, y: 0.19), side: .right, labelY: 0.30),
            .init(id: 0xDA, name: "DPI button",     point: .init(x: 0.61, y: 0.36), side: .right, labelY: 0.48),
            .init(id: 0xC4, name: "Top button",     point: .init(x: 0.60, y: 0.46), side: .right, labelY: 0.64),
        ]
        }
    }

    /// Where the common controls sit on the ergonomic drawing.
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

/// Body style of the illustrated mouse.
public enum MouseShape: Sendable, Hashable {
    /// Ergonomic with a thumb rest (MX Master family).
    case ergonomic
    /// Small symmetrical body (MX Anywhere family).
    case compact
    /// Upright "vertical" body (MX Vertical).
    case vertical

    /// Pick a style from a product name such as "MX Anywhere 3S".
    public static func forModel(_ name: String) -> MouseShape {
        let n = name.lowercased()
        if n.contains("anywhere") { return .compact }
        if n.contains("vertical") { return .vertical }
        return .ergonomic
    }
}

/// An illustrated mouse with a callout per control. Tapping a callout or its dot selects it.
///
/// The drawing is original, generic artwork — not a picture of any specific product.
public struct MouseMapView: View {
    public let hotspots: [MouseHotspot]
    /// What each control currently does, by CID (e.g. "Mission Control").
    public let actions: [UInt16: String]
    /// Controls currently held down on the real mouse; they light up green.
    public let pressed: Set<UInt16>
    public let shape: MouseShape
    @Binding public var selected: UInt16?

    public init(hotspots: [MouseHotspot], actions: [UInt16: String], pressed: Set<UInt16> = [],
                shape: MouseShape = .ergonomic, selected: Binding<UInt16?>) {
        self.hotspots = hotspots
        self.actions = actions
        self.pressed = pressed
        self.shape = shape
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
                MouseArt(shape: shape,
                         selected: selected.flatMap { id in hotspots.first { $0.id == id } },
                         pressed: hotspots.filter { pressed.contains($0.id) })
                    .frame(width: art, height: art)
                    .position(x: w / 2, y: h / 2)
                    .accessibilityHidden(true)

                // Leader lines — short horizontal run out of the callout, then straight to the dot.
                ForEach(hotspots) { hs in
                    let p = CGPoint(x: ax + hs.point.x * art, y: hs.point.y * art)
                    let edge = CGPoint(x: hs.side == .left ? 12 + chipW : w - 12 - chipW, y: hs.labelY * h)
                    let elbow = CGPoint(x: edge.x + (hs.side == .left ? 26 : -26), y: edge.y)
                    let on = selected == hs.id
                    let down = pressed.contains(hs.id)
                    Path { path in
                        path.move(to: edge)
                        path.addLine(to: elbow)
                        path.addLine(to: p)
                    }
                    .stroke(down ? Color.green : (on ? Color.accentColor : Color.primary.opacity(0.28)),
                            style: StrokeStyle(lineWidth: (on || down) ? 1.8 : 1, lineCap: .round, lineJoin: .round))
                    .accessibilityHidden(true)
                }

                // Dots
                ForEach(hotspots) { hs in
                    let p = CGPoint(x: ax + hs.point.x * art, y: hs.point.y * art)
                    let down = pressed.contains(hs.id)
                    let tint: Color = down ? .green : .accentColor
                    Circle()
                        .fill(down || selected == hs.id ? tint : Color.white)
                        .frame(width: down ? 15 : (selected == hs.id ? 12 : 9), height: down ? 15 : (selected == hs.id ? 12 : 9))
                        .overlay(Circle().strokeBorder(tint.opacity(0.9), lineWidth: 1.5))
                        .shadow(color: tint.opacity(down ? 0.9 : (selected == hs.id ? 0.6 : 0.25)), radius: down ? 9 : 5)
                        .position(p)
                        .onTapGesture { selected = hs.id }
                        .accessibilityHidden(true)   // the callout below is the accessible control
                }

                // Callouts
                ForEach(hotspots) { hs in
                    let isOn = selected == hs.id
                    let isDown = pressed.contains(hs.id)
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
                        .glassSurface(cornerRadius: 12, tint: isDown ? .green : (isOn ? .accentColor : nil),
                                      shadowRadius: (isOn || isDown) ? 10 : 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isDown ? Color.green : Color.accentColor.opacity(isOn ? 0.8 : 0),
                                              lineWidth: isDown ? 1.8 : 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(hs.name), \(actions[hs.id] ?? "Default")")
                    .accessibilityValue(isDown ? "pressed" : "")
                    .accessibilityHint("Shows the settings for this control")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .position(x: hs.side == .left ? 12 + chipW / 2 : w - 12 - chipW / 2, y: hs.labelY * h)
                }
            }
        }
    }
}

// MARK: - Layout

/// Where each physical part sits for a body style, in unit coordinates (0…1 of the artwork square).
struct MouseLayout {
    struct Part {
        var center: CGPoint
        var size: CGSize
        var degrees: Double = 0
    }
    struct Curve { var to: CGPoint; var c1: CGPoint; var c2: CGPoint }

    var start: CGPoint
    var curves: [Curve]
    /// Grooves between the buttons (vertical splits).
    var seamSegments: [(CGPoint, CGPoint)]
    /// The groove under the click buttons; its y also bounds the raised button panel.
    var seamFrom: CGPoint
    var seamTo: CGPoint
    var seamControl: CGPoint
    var wheel: Part
    var capsules: [Part]
    var ellipses: [Part]
    var circles: [Part]
    /// Textured thumb rest, if the body has one: its outline and the area the dots cover.
    var grip: Part?
    var gripBox: CGRect = .zero
    var highlight: UnitPoint
    var softbox: CGPoint

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private static func curve(_ x: CGFloat, _ y: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Curve {
        Curve(to: pt(x, y), c1: pt(x1, y1), c2: pt(x2, y2))
    }

    static func make(_ shape: MouseShape) -> MouseLayout {
        switch shape {
        case .ergonomic:
            return MouseLayout(
                start: pt(0.36, 0.10),
                curves: [
                    curve(0.69, 0.10, 0.48, 0.05, 0.58, 0.05), curve(0.79, 0.40, 0.76, 0.10, 0.80, 0.25),
                    curve(0.76, 0.78, 0.79, 0.55, 0.78, 0.68), curve(0.60, 0.93, 0.74, 0.88, 0.68, 0.93),
                    curve(0.40, 0.93, 0.55, 0.95, 0.45, 0.95), curve(0.26, 0.84, 0.34, 0.92, 0.29, 0.90),
                    curve(0.18, 0.62, 0.20, 0.80, 0.15, 0.70), curve(0.28, 0.45, 0.20, 0.54, 0.25, 0.50),
                    curve(0.36, 0.10, 0.31, 0.30, 0.32, 0.18),
                ],
                seamSegments: [(pt(0.525, 0.065), pt(0.525, 0.13)), (pt(0.525, 0.28), pt(0.525, 0.31))],
                seamFrom: pt(0.335, 0.33), seamTo: pt(0.745, 0.33), seamControl: pt(0.54, 0.385),
                wheel: Part(center: pt(0.525, 0.205), size: CGSize(width: 0.072, height: 0.155)),
                capsules: [
                    Part(center: pt(0.305, 0.355), size: CGSize(width: 0.03, height: 0.09), degrees: -8),      // side wheel
                    Part(center: pt(0.285, 0.43), size: CGSize(width: 0.078, height: 0.042), degrees: -62),    // forward
                    Part(center: pt(0.272, 0.53), size: CGSize(width: 0.078, height: 0.042), degrees: -70),    // back
                    Part(center: pt(0.525, 0.37), size: CGSize(width: 0.072, height: 0.03)),                   // top button
                ],
                ellipses: [Part(center: pt(0.235, 0.69), size: CGSize(width: 0.064, height: 0.074))],          // gesture
                circles: [Part(center: pt(0.62, 0.50), size: CGSize(width: 0.036, height: 0.036))],            // DPI
                grip: Part(center: pt(0.235, 0.69), size: CGSize(width: 0.13, height: 0.32), degrees: 12),
                gripBox: CGRect(x: 0.16, y: 0.52, width: 0.15, height: 0.34),
                highlight: UnitPoint(x: 0.42, y: 0.20), softbox: pt(0.60, 0.26))

        case .compact:
            return MouseLayout(
                start: pt(0.37, 0.16),
                curves: [
                    curve(0.63, 0.16, 0.45, 0.11, 0.55, 0.11), curve(0.73, 0.42, 0.70, 0.17, 0.74, 0.28),
                    curve(0.70, 0.76, 0.73, 0.56, 0.72, 0.68), curve(0.50, 0.86, 0.68, 0.83, 0.60, 0.86),
                    curve(0.30, 0.76, 0.40, 0.86, 0.32, 0.83), curve(0.27, 0.42, 0.28, 0.68, 0.27, 0.56),
                    curve(0.37, 0.16, 0.28, 0.28, 0.31, 0.16),
                ],
                seamSegments: [(pt(0.5, 0.125), pt(0.5, 0.185)), (pt(0.5, 0.325), pt(0.5, 0.355))],
                seamFrom: pt(0.31, 0.34), seamTo: pt(0.69, 0.34), seamControl: pt(0.5, 0.385),
                wheel: Part(center: pt(0.5, 0.255), size: CGSize(width: 0.07, height: 0.14)),
                capsules: [
                    Part(center: pt(0.29, 0.50), size: CGSize(width: 0.08, height: 0.04), degrees: -82),       // forward
                    Part(center: pt(0.29, 0.585), size: CGSize(width: 0.08, height: 0.04), degrees: -86),      // back
                    Part(center: pt(0.5, 0.43), size: CGSize(width: 0.07, height: 0.03)),                      // top button
                ],
                ellipses: [Part(center: pt(0.30, 0.68), size: CGSize(width: 0.06, height: 0.07))],             // gesture
                circles: [],
                grip: nil,
                highlight: UnitPoint(x: 0.45, y: 0.28), softbox: pt(0.56, 0.30))

        case .vertical:
            return MouseLayout(
                start: pt(0.42, 0.10),
                curves: [
                    curve(0.62, 0.12, 0.50, 0.06, 0.58, 0.07), curve(0.72, 0.36, 0.68, 0.18, 0.73, 0.27),
                    curve(0.69, 0.80, 0.71, 0.54, 0.72, 0.70), curve(0.52, 0.92, 0.67, 0.88, 0.60, 0.92),
                    curve(0.35, 0.86, 0.45, 0.92, 0.38, 0.90), curve(0.31, 0.45, 0.32, 0.75, 0.29, 0.60),
                    curve(0.42, 0.10, 0.32, 0.30, 0.35, 0.16),
                ],
                seamSegments: [(pt(0.53, 0.07), pt(0.53, 0.115)), (pt(0.53, 0.265), pt(0.53, 0.30))],
                seamFrom: pt(0.34, 0.30), seamTo: pt(0.70, 0.30), seamControl: pt(0.53, 0.35),
                wheel: Part(center: pt(0.53, 0.19), size: CGSize(width: 0.07, height: 0.15)),
                capsules: [
                    Part(center: pt(0.335, 0.40), size: CGSize(width: 0.075, height: 0.04), degrees: -72),     // forward
                    Part(center: pt(0.33, 0.50), size: CGSize(width: 0.075, height: 0.04), degrees: -78),      // back
                    Part(center: pt(0.60, 0.46), size: CGSize(width: 0.05, height: 0.028)),                    // top button
                ],
                ellipses: [],
                circles: [Part(center: pt(0.61, 0.36), size: CGSize(width: 0.036, height: 0.036))],            // DPI
                grip: nil,
                highlight: UnitPoint(x: 0.45, y: 0.18), softbox: pt(0.58, 0.25))
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

/// Generic top-down mouse, drawn from paths with layered shading.
struct MouseArt: View {
    let shape: MouseShape
    let selected: MouseHotspot?
    var pressed: [MouseHotspot] = []
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let layout = MouseLayout.make(shape)
        GeometryReader { geo in
            let s = geo.size.width
            let dark = scheme == .dark
            ZStack {
                // Ground shadow: a tight contact shadow plus a wide ambient one.
                MouseBody(layout: layout).fill(Color.black.opacity(dark ? 0.26 : 0.20)).blur(radius: s * 0.014).offset(x: s * 0.016, y: s * 0.05)
                MouseBody(layout: layout).fill(Color.black.opacity(dark ? 0.45 : 0.28)).blur(radius: s * 0.005).offset(x: s * 0.007, y: s * 0.03)

                // Side wall: the outline swept down and to the right, merged into one path, so the
                // shell has visible thickness. Lit near the top edge, dark toward the desk.
                wall(layout, s)
                    .fill(LinearGradient(colors: [Color(white: dark ? 0.30 : 0.40), Color(white: dark ? 0.05 : 0.15)],
                                         startPoint: .top, endPoint: .bottom))

                // Shell: a dome — bright crest up and to the left, falling off to the lower right.
                MouseBody(layout: layout)
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
                    let y = layout.seamFrom.y
                    p.move(to: pt(0, 0, s)); p.addLine(to: pt(1, 0, s)); p.addLine(to: pt(1, y, s))
                    p.addLine(to: pt(layout.seamTo.x, y, s))
                    p.addQuadCurve(to: pt(layout.seamFrom.x, y, s), control: pt(layout.seamControl.x, layout.seamControl.y, s))
                    p.addLine(to: pt(0, y, s)); p.closeSubpath()
                }
                .fill(Color.white.opacity(dark ? 0.07 : 0.10))
                .mask(MouseBody(layout: layout))

                // Inner shadow around the edge gives the shell volume.
                MouseBody(layout: layout)
                    .stroke(Color.black.opacity(0.55), lineWidth: s * 0.07)
                    .blur(radius: s * 0.028)
                    .clipShape(MouseBody(layout: layout))

                // Soft top light and a diagonal specular streak.
                MouseBody(layout: layout)
                    .fill(RadialGradient(colors: [.white.opacity(dark ? 0.26 : 0.34), .clear],
                                         center: layout.highlight, startRadius: 0, endRadius: s * 0.46))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.13), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.10, height: s * 1.2)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -s * 0.08, y: -s * 0.02)
                    .mask(MouseBody(layout: layout))

                // Softbox reflection on the dome
                RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(dark ? 0.22 : 0.30), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.26, height: s * 0.34)
                    .rotationEffect(.degrees(-14))
                    .blur(radius: s * 0.012)
                    .position(pt(layout.softbox.x, layout.softbox.y, s))
                    .mask(MouseBody(layout: layout))
                // A thin bright edge where the dome meets the wall, lower right.
                MouseBody(layout: layout)
                    .stroke(LinearGradient(colors: [.clear, .white.opacity(0.0), .white.opacity(0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .blur(radius: 0.6)

                // Rim light
                MouseBody(layout: layout)
                    .stroke(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.04), .white.opacity(0.28)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)

                // Button seams, embossed: a dark groove with a light edge just below it.
                seams(layout, s, color: .black.opacity(0.6), dy: 0)
                seams(layout, s, color: .white.opacity(0.18), dy: 1.2)

                // Rubber grip texture on the thumb rest (bodies that have one).
                if let grip = layout.grip {
                    Canvas { ctx, size in
                        let step = size.width * 0.022
                        let box = layout.gripBox
                        var y = size.height * box.minY
                        var row = 0
                        while y < size.height * box.maxY {
                            var x = size.width * box.minX + (row % 2 == 0 ? 0 : step / 2)
                            while x < size.width * box.maxX {
                                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                                         with: .color(.white.opacity(0.16)))
                                x += step
                            }
                            y += step
                            row += 1
                        }
                    }
                    .mask(
                        Ellipse().frame(width: s * grip.size.width, height: s * grip.size.height)
                            .rotationEffect(.degrees(grip.degrees))
                            .position(pt(grip.center.x, grip.center.y, s))
                    )
                }

                // Scroll wheel: dark well, metallic ridged wheel.
                let wheel = layout.wheel
                RoundedRectangle(cornerRadius: s * 0.034, style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: s * wheel.size.width, height: s * wheel.size.height)
                    .position(pt(wheel.center.x, wheel.center.y, s))
                RoundedRectangle(cornerRadius: s * 0.028, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.82), Color(white: 0.30)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * wheel.size.width * 0.75, height: s * wheel.size.height * 0.89)
                    .overlay(
                        VStack(spacing: s * 0.0075) {
                            ForEach(0..<13, id: \.self) { _ in
                                Rectangle().fill(Color.black.opacity(0.32)).frame(height: 0.9)
                            }
                        }
                        .padding(.vertical, s * 0.01)
                        .clipShape(RoundedRectangle(cornerRadius: s * 0.028, style: .continuous))
                    )
                    .position(pt(wheel.center.x, wheel.center.y, s))

                // Keys: capsules (side wheel, back/forward, top button), the gesture button and DPI button.
                ForEach(Array(layout.capsules.enumerated()), id: \.offset) { _, part in
                    Key(shape: Capsule()).frame(width: s * part.size.width, height: s * part.size.height)
                        .rotationEffect(.degrees(part.degrees)).position(pt(part.center.x, part.center.y, s))
                }
                ForEach(Array(layout.ellipses.enumerated()), id: \.offset) { _, part in
                    Key(shape: Ellipse()).frame(width: s * part.size.width, height: s * part.size.height)
                        .overlay(Ellipse().strokeBorder(.white.opacity(0.18), lineWidth: 0.8).padding(s * 0.011))
                        .position(pt(part.center.x, part.center.y, s))
                }
                ForEach(Array(layout.circles.enumerated()), id: \.offset) { _, part in
                    Key(shape: Circle()).frame(width: s * part.size.width, height: s * part.size.height)
                        .position(pt(part.center.x, part.center.y, s))
                }

                // Green flash on controls held down on the real mouse.
                ForEach(pressed) { hs in
                    Circle()
                        .fill(Color.green.opacity(0.55))
                        .frame(width: s * 0.15, height: s * 0.15)
                        .blur(radius: 8)
                        .position(pt(hs.point.x, hs.point.y, s))
                }

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

    private func wall(_ layout: MouseLayout, _ s: CGFloat) -> Path {
        let outline = MouseBody(layout: layout).path(in: CGRect(x: 0, y: 0, width: s, height: s))
        var swept = outline
        for i in 1...9 {
            let shift = CGAffineTransform(translationX: s * 0.0013 * CGFloat(i), y: s * 0.0062 * CGFloat(i))
            swept = swept.union(outline.applying(shift))
        }
        return swept
    }

    private func seams(_ layout: MouseLayout, _ s: CGFloat, color: Color, dy: CGFloat) -> some View {
        Path { p in
            for (a, b) in layout.seamSegments {
                p.move(to: pt(a.x, a.y, s)); p.addLine(to: pt(b.x, b.y, s))
            }
            p.move(to: pt(layout.seamFrom.x, layout.seamFrom.y, s))
            p.addQuadCurve(to: pt(layout.seamTo.x, layout.seamTo.y, s),
                           control: pt(layout.seamControl.x, layout.seamControl.y, s))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        .offset(y: dy)
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
}

struct MouseBody: Shape {
    let layout: MouseLayout

    func path(in rect: CGRect) -> Path {
        let s = rect.width
        func p(_ pt: CGPoint) -> CGPoint { CGPoint(x: rect.minX + pt.x * s, y: rect.minY + pt.y * s) }
        var path = Path()
        path.move(to: p(layout.start))
        for c in layout.curves {
            path.addCurve(to: p(c.to), control1: p(c.c1), control2: p(c.c2))
        }
        path.closeSubpath()
        return path
    }
}
