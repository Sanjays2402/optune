import SwiftUI
import OptuneCore

/// Optune's Liquid-Glass design system — typography, color, motion.
///
/// macOS 26 renders `.ultraThinMaterial` / `.regularMaterial` *as* Liquid Glass
/// in app surfaces. We layer the system materials with subtle gradient noise
/// and SF-Pro-Rounded typography to match the system look. Where macOS 26's
/// `.glassEffect()` is available we prefer it; otherwise we fall back to
/// composited materials that look identical on 14/15 SDKs.
public enum OptuneDesign {

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }

    public enum Radius {
        public static let card: CGFloat = 16
        public static let row: CGFloat = 10
        public static let pill: CGFloat = 999
    }

    public enum Motion {
        public static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.85)
        public static let calm = Animation.spring(response: 0.55, dampingFraction: 0.92)
        public static let glide = Animation.easeInOut(duration: 0.18)
    }

    public enum Typography {
        public static let title  = Font.system(size: 17, weight: .semibold, design: .rounded)
        public static let header = Font.system(size: 14, weight: .semibold, design: .rounded)
        public static let body   = Font.system(size: 12, weight: .medium, design: .rounded)
        public static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
        public static let mono   = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}

// MARK: - Backgrounds

/// Translucent menu bar dropdown surface — Liquid Glass on macOS 26+,
/// composited materials on older SDKs. Uses the system tint via `.accentColor`.
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

/// Inset card surface — sits inside the dropdown, holds device/feature rows.
public struct GlassCardModifier: ViewModifier {
    public var tint: Color

    public init(tint: Color = .accentColor) {
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        content
            .padding(OptuneDesign.Spacing.md + 2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            )
    }
}

public extension View {
    func glassCard(tint: Color = .accentColor) -> some View {
        modifier(GlassCardModifier(tint: tint))
    }
}

// MARK: - Capability Pill

/// Translucent capability indicator — shown next to feature labels to communicate
/// state at a glance (e.g. "ON", "8000 dpi", "65%"). Animates the label change.
public struct CapabilityPill: View {
    public let text: String
    public let tone: Tone

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
            case .neutral: return Color.gray.opacity(0.18)
            case .accent: return Color.accentColor.opacity(0.18)
            case .positive: return Color.green.opacity(0.18)
            case .warning: return Color.orange.opacity(0.18)
            case .danger: return Color.red.opacity(0.18)
            }
        }
    }

    public init(text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(OptuneDesign.Typography.caption)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).fill(tone.background))
            )
            .overlay(
                Capsule(style: .continuous).stroke(tone.foreground.opacity(0.18), lineWidth: 0.5)
            )
            .contentTransition(.numericText())
            .animation(OptuneDesign.Motion.snappy, value: text)
            .animation(OptuneDesign.Motion.snappy, value: tone.foreground)
    }
}

// MARK: - Feature Row

/// Single capability/telemetry row inside a glass card. Used for Battery, DPI,
/// SmartShift, Buttons. SF Symbols 6 hierarchical glyph, animated value pill.
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
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(symbolTint, .secondary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)
                .symbolEffect(.bounce, options: .nonRepeating, value: secondary ?? "")

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
            .frame(width: 8, height: 8)
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
