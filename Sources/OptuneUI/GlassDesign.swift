import SwiftUI
import OptuneCore

/// Optune's Liquid-Glass design system — typography, color, motion, surfaces.
///
/// macOS 26 renders `.ultraThinMaterial` / `.regularMaterial` as Liquid Glass
/// in app surfaces. We layer system materials with subtle gradient noise and
/// SF-Pro-Rounded typography to match the system look. Where macOS 26's
/// `.glassEffect()` is available we prefer it; otherwise we fall back to
/// composited materials that look identical on 14/15 SDKs.
public enum OptuneDesign {

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs:  CGFloat = 4
        public static let sm:  CGFloat = 8
        public static let md:  CGFloat = 12
        public static let lg:  CGFloat = 16
        public static let xl:  CGFloat = 20
        public static let xxl: CGFloat = 28
    }

    public enum Radius {
        public static let card: CGFloat = 18
        public static let group: CGFloat = 12
        public static let row: CGFloat = 8
        public static let pill: CGFloat = 999
    }

    public enum Motion {
        public static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.85)
        public static let calm   = Animation.spring(response: 0.55, dampingFraction: 0.92)
        public static let glide  = Animation.easeInOut(duration: 0.18)
        public static let press  = Animation.easeOut(duration: 0.10)
    }

    /// Modern macOS-26-style type scale.  Numbers chosen to give clear ratios at
    /// a 1.20 typographic step: 28 → 22 → 17 → 14 → 13 → 11 → 10.
    public enum Typography {
        public static let display = Font.system(size: 28, weight: .bold,    design: .rounded)
        public static let title   = Font.system(size: 22, weight: .semibold, design: .rounded)
        public static let title2  = Font.system(size: 17, weight: .semibold, design: .rounded)
        public static let header  = Font.system(size: 14, weight: .semibold, design: .rounded)
        public static let body    = Font.system(size: 13, weight: .medium,   design: .rounded)
        public static let value   = Font.system(size: 13, weight: .semibold, design: .rounded)
        public static let caption = Font.system(size: 11, weight: .medium,   design: .rounded)
        public static let footnote = Font.system(size: 10, weight: .medium,  design: .rounded)
        public static let mono    = Font.system(size: 11, weight: .regular,  design: .monospaced)
        public static let section = Font.system(size: 10, weight: .bold,     design: .rounded)
    }

    public enum Layer {
        /// hairline divider tint that adapts to dark/light modes.
        public static let divider = Color.primary.opacity(0.08)
        public static let strokeStrong = Color.primary.opacity(0.12)
        public static let strokeSoft   = Color.primary.opacity(0.06)
        public static let highlight    = Color.white.opacity(0.06)
    }
}

// MARK: - Section header (uppercase tracked label)

public struct SectionHeader: View {
    public let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title.uppercased())
            .font(OptuneDesign.Typography.section)
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, OptuneDesign.Spacing.md)
            .padding(.top, OptuneDesign.Spacing.sm)
            .padding(.bottom, OptuneDesign.Spacing.xs)
    }
}

// MARK: - Inset group (Linear/macOS-style grouped list)

/// A grouped surface that hosts a vertical stack of `InsetRow`s with hairline
/// dividers between them.  Used to consolidate per-setting cards into a single
/// rounded surface — the modern macOS System Settings pattern.
public struct InsetGroup<Content: View>: View {
    public let content: Content
    public let tint: Color?

    public init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                    .fill(.regularMaterial)
                if let tint {
                    RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.08), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                RoundedRectangle(cornerRadius: OptuneDesign.Radius.group, style: .continuous)
                    .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 3)
    }
}

/// Row inside an `InsetGroup`. Hairline divider above (except first) and 14×12
/// inset padding by default. Use `.divided()` on the *parent* to inject hairlines.
public struct InsetRow<Leading: View, Trailing: View>: View {
    public let title: String
    public let subtitle: String?
    @ViewBuilder public let leading: () -> Leading
    @ViewBuilder public let trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .center, spacing: OptuneDesign.Spacing.md) {
            leading()
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(OptuneDesign.Typography.body)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: OptuneDesign.Spacing.md)
            trailing()
        }
        .padding(.horizontal, OptuneDesign.Spacing.lg - 2)
        .padding(.vertical, OptuneDesign.Spacing.md)
    }
}

/// Hairline divider between rows in an `InsetGroup`.
public struct GroupDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(OptuneDesign.Layer.divider)
            .frame(height: 0.5)
            .padding(.leading, OptuneDesign.Spacing.lg + 26)
    }
}

// MARK: - Backgrounds

/// Page background for Settings detail panes — sits behind grouped lists.
/// Uses adaptive `windowBackgroundColor` for proper light/dark fidelity.
public struct PageBackground: View {
    public init() {}
    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            // very subtle radial glow tinted by accent — Linear / macOS 26 style.
            RadialGradient(
                colors: [Color.accentColor.opacity(0.06), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }
}

/// Translucent menu bar dropdown surface — Liquid Glass on macOS 26+,
/// composited materials on older SDKs.
public struct LiquidGlassSurface: View {
    public init() {}
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
            RoundedRectangle(cornerRadius: OptuneDesign.Radius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

/// Inset card surface — sits inside the dropdown / detail pane, holds device
/// or feature rows. Subtler than the menu-bar surface but slightly elevated.
public struct GlassCardModifier: ViewModifier {
    public var tint: Color
    public var padding: CGFloat

    public init(tint: Color = .accentColor, padding: CGFloat = OptuneDesign.Spacing.md + 2) {
        self.tint = tint
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.10), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(OptuneDesign.Layer.strokeSoft, lineWidth: 0.5)
                }
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }
}

public extension View {
    func glassCard(tint: Color = .accentColor, padding: CGFloat = OptuneDesign.Spacing.md + 2) -> some View {
        modifier(GlassCardModifier(tint: tint, padding: padding))
    }

    /// Apply to a section header followed by an `InsetGroup` to get the
    /// canonical macOS-26 grouped-settings look with consistent spacing.
    func sectionGroupSpacing() -> some View {
        padding(.bottom, OptuneDesign.Spacing.lg)
    }
}

// MARK: - Capability Pill

/// Translucent capability indicator — shown next to feature labels to communicate
/// state at a glance (e.g. "ON", "8000 dpi", "65%"). Animates the label change.
public struct CapabilityPill: View {
    public let text: String
    public let tone: Tone
    public let style: Style

    public enum Style { case filled, outline }
    public enum Tone {
        case neutral, accent, positive, warning, danger

        public var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .accent: return .accentColor
            case .positive: return .green
            case .warning: return .orange
            case .danger: return .red
            }
        }

        public var background: Color {
            switch self {
            case .neutral: return Color.gray.opacity(0.16)
            case .accent: return Color.accentColor.opacity(0.16)
            case .positive: return Color.green.opacity(0.16)
            case .warning: return Color.orange.opacity(0.16)
            case .danger: return Color.red.opacity(0.16)
            }
        }
    }

    public init(text: String, tone: Tone, style: Style = .filled) {
        self.text = text
        self.tone = tone
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(OptuneDesign.Typography.caption)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(style == .filled ? tone.background : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tone.foreground.opacity(style == .outline ? 0.45 : 0.18), lineWidth: 0.5)
            )
            .contentTransition(.numericText())
            .animation(OptuneDesign.Motion.snappy, value: text)
            .animation(OptuneDesign.Motion.snappy, value: tone.foreground)
    }
}

// MARK: - Connection chip (replaces old border-pill "Connected" badge)

/// Minimalist online/offline chip — single dot + label, no pill chrome.
/// Matches Linear / Raycast aesthetic.
public struct ConnectionChip: View {
    public let connected: Bool
    public let label: String

    public init(connected: Bool, label: String? = nil) {
        self.connected = connected
        self.label = label ?? (connected ? "Connected" : "Offline")
    }

    public var body: some View {
        HStack(spacing: 6) {
            StatusDot(tone: connected ? .green : .red, pulse: connected)
            Text(label)
                .font(OptuneDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Feature Row

/// Single capability/telemetry row inside a glass card. Used for Battery, DPI,
/// SmartShift, Buttons. SF Symbols hierarchical glyph, animated value pill.
public struct FeatureRow<Trailing: View>: View {
    public let symbol: String
    public let symbolTint: Color
    public let label: String
    public let secondary: String?
    @ViewBuilder public let trailing: () -> Trailing

    public init(
        symbol: String,
        symbolTint: Color = .accentColor,
        label: String,
        secondary: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.label = label
        self.secondary = secondary
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(symbolTint.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(symbolTint)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, options: .nonRepeating, value: secondary ?? "")
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(OptuneDesign.Typography.body)
                if let secondary {
                    Text(secondary)
                        .font(OptuneDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            trailing()
        }
    }
}

public extension FeatureRow where Trailing == EmptyView {
    init(
        symbol: String,
        symbolTint: Color = .accentColor,
        label: String,
        secondary: String? = nil
    ) {
        self.init(symbol: symbol, symbolTint: symbolTint, label: label, secondary: secondary, trailing: { EmptyView() })
    }
}

// MARK: - Status Dot

public struct StatusDot: View {
    public enum Tone {
        case green, amber, red, gray
        public var color: Color {
            switch self {
            case .green: return .green
            case .amber: return .orange
            case .red:   return .red
            case .gray:  return .secondary
            }
        }
    }

    public let tone: Tone
    public let pulse: Bool

    @State private var scale: CGFloat = 1

    public init(tone: Tone, pulse: Bool) {
        self.tone = tone
        self.pulse = pulse
    }

    public var body: some View {
        Circle()
            .fill(tone.color)
            .frame(width: 7, height: 7)
            .overlay(
                Circle()
                    .stroke(tone.color.opacity(0.35), lineWidth: 4)
                    .scaleEffect(pulse ? scale : 1)
                    .opacity(pulse ? 2 - scale : 0)
            )
            .onAppear {
                guard pulse else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    scale = 1.9
                }
            }
    }
}

// MARK: - Keyboard shortcut glyph

/// Right-aligned `⌘R` style keyboard hint — used in menu rows for affordance.
public struct KeyHint: View {
    public let keys: [String]
    public init(_ keys: String...) { self.keys = keys }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(keys.indices, id: \.self) { i in
                Text(keys[i])
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 14)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - Ghost button (subtle secondary action)

public struct GhostButtonStyle: ButtonStyle {
    public var tint: Color
    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OptuneDesign.Typography.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed
                          ? tint.opacity(0.18)
                          : tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tint.opacity(0.15), lineWidth: 0.5)
            )
            .foregroundStyle(tint)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(OptuneDesign.Motion.press, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
    static func ghost(tint: Color) -> GhostButtonStyle { GhostButtonStyle(tint: tint) }
}

// MARK: - Skeleton loader

/// Pulsing rounded placeholder used while telemetry is loading. More modern
/// than a static "Reading…" string + spinner combo.
public struct Skeleton: View {
    public let height: CGFloat
    public let cornerRadius: CGFloat
    @State private var animate = false

    public init(height: CGFloat = 14, cornerRadius: CGFloat = 6) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.06),
                        Color.primary.opacity(0.16),
                        Color.primary.opacity(0.06)
                    ],
                    startPoint: animate ? .leading : .trailing,
                    endPoint:   animate ? .trailing : .leading
                )
            )
            .frame(height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
