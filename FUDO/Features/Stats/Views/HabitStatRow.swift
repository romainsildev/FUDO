import SwiftUI

/// One habit in the "BY HABIT" list (frame 05): icon tile + name + 7-day sparkline +
/// completion % with its trend arrow + a chevron. The whole card is the push affordance
/// to the habit detail. Icons are the rule's SF Symbol (real data — the frame's emoji
/// aren't stored; consistent with the Home checklist rows).
struct HabitStatRow: View {
    let habit: HabitStat
    let period: StatsPeriod

    var body: some View {
        NavigationLink(value: HabitDetailRoute(ruleID: habit.id, period: period)) {
            HStack(spacing: 12) {
                iconTile
                Text(habit.title)
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                HabitSparkline(days: habit.sparkline)

                VStack(spacing: 2) {
                    Text("\(habit.completionPercent)%")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundStyle(FudoColor.textPrimary)
                    TrendArrow(trend: habit.trend, size: 10)
                }
                .frame(width: 46)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .padding(FudoSpacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
                    .strokeBorder(FudoColor.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.title), \(habit.completionPercent) percent")
        .accessibilityHint("Opens habit detail")
    }

    private var iconTile: some View {
        Image(systemName: habit.iconName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(FudoColor.textPrimary)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                    .fill(FudoColor.bgPrimary)
            }
    }
}
