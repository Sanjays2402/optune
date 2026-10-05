import SwiftUI

/// Optune's own mouse mark — plain shapes, used for the logo tiles. (Apple's SF
/// Symbols licence doesn't allow symbols in logos or icons, so the brand mark
/// is drawn here instead.)
public struct MouseMark: View {
    public let height: CGFloat

    public init(height: CGFloat) { self.height = height }

    private let ink = Color(red: 0.10, green: 0.25, blue: 0.65)

    public var body: some View {
        let w = height * 0.66
        ZStack(alignment: .top) {
            Capsule(style: .continuous).fill(Color.white.opacity(0.97))
            Rectangle()
                .fill(ink.opacity(0.30))
                .frame(height: max(1, height * 0.022))
                .padding(.horizontal, w * 0.05)
                .offset(y: height * 0.42)
            Capsule(style: .continuous)
                .fill(ink)
                .frame(width: w * 0.14, height: height * 0.17)
                .offset(y: height * 0.12)
        }
        .frame(width: w, height: height)
        .shadow(color: .black.opacity(0.25), radius: height * 0.08, y: height * 0.03)
    }
}
