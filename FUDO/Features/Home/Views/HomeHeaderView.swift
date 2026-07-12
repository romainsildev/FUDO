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

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAvatarTap) {
                SenseiAvatarView(rank: rank)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your sensei — open Progress")

            Text(dayPillLabel)
                .font(.system(size: 13, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .fudoGlassCapsule(shadow: false)

            Spacer()

            Button(action: onFlameTap) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(streakIsAlive
                                         ? AnyShapeStyle(FudoGradient.flame)
                                         : AnyShapeStyle(FudoColor.textSecondary))
                    Text("\(streak)")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundStyle(streakIsAlive ? FudoColor.textPrimary : FudoColor.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .fudoGlassCapsule(strong: streakIsAlive, shadow: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(streak) day streak — open details")
        }
    }
}
