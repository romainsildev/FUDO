import SwiftUI

/// The habit-detail hero (Habit FINAL v3-B3, 2026-07-24): a compact card — the challenge
/// completion % blown up on the left, a gold flame streak chip on the right. Replaces the
/// three-tile row (`HabitTilesRow` is orphaned). Cream on the number (an achievement, not
/// an alarm); gold is the flame's own colour, not a celebration burst.
struct HabitHeroCard: View {
    let completionPercent: Int
    let dayNumber: Int
    let durationDays: Int
    let streak: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(completionPercent)%")
                    .fudoFont(.metric(40))
                    .tracking(-2)
                    .foregroundStyle(FudoColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("HELD — DAY \(dayNumber) OF \(durationDays)")
                    .fudoFont(.label(11))
                    .kerning(1)
                    .foregroundStyle(FudoColor.textSecondary)
            }

            Spacer(minLength: 0)

            streakChip
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    @ViewBuilder private var streakChip: some View {
        if streak > 0 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .fudoFont(.glyph(12, weight: .bold))
                    .foregroundStyle(FudoColor.celebrationGold)
                Text("\(streak) day streak")
                    .fudoFont(.headline(13, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(FudoColor.surfaceGlass)
                    .overlay(Capsule().strokeBorder(FudoColor.celebrationGold.opacity(0.4), lineWidth: 1))
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
        }
    }
}

#if DEBUG
#Preview("Habit hero") {
    VStack(spacing: 16) {
        HabitHeroCard(completionPercent: 92, dayNumber: 12, durationDays: 30, streak: 4)
        HabitHeroCard(completionPercent: 57, dayNumber: 12, durationDays: 30, streak: 0)
    }
    .padding(FudoSpacing.screenMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}
#endif
