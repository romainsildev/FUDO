import SwiftUI

/// Home header (D2 — three elements, factual, no drama): sensei head avatar → Progress,
/// a static day pill, a flame pill → flame sheet.
struct HomeHeaderView: View {
    let rank: Rank
    let dayPillLabel: String
    let streak: Int
    let streakIsAlive: Bool
    let onAvatarTap: () -> Void
    let onFlameTap: () -> Void

    /// Every header element shares this height so avatar and both pills line up
    /// on one row — no more staggered tops (device feedback 2026-07-13).
    private static let elementHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAvatarTap) {
                SenseiAvatarView(rank: rank, diameter: Self.elementHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your sensei — open Progress")

            Text(dayPillLabel)
                .fudoFont(.label(13, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: Self.elementHeight)
                .fudoGlassCapsule(shadow: false)

            Spacer()

            Button(action: onFlameTap) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .fudoFont(.stat(14, weight: .semibold))
                        .foregroundStyle(streakIsAlive
                                         ? AnyShapeStyle(FudoGradient.flame)
                                         : AnyShapeStyle(FudoColor.textSecondary))
                    Text("\(streak)")
                        .fudoFont(.stat(14))
                        .foregroundStyle(streakIsAlive ? FudoColor.textPrimary : FudoColor.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: Self.elementHeight)
                .fudoGlassCapsule(strong: streakIsAlive, shadow: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(streak) day streak — open details")
        }
    }
}
