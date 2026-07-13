import SwiftUI

/// Habit-detail completion graph (frame 05b): one bar per day (7d) or per week
/// (30d / challenge). Filled vermillon = done, dead = missed; the in-progress day
/// reads as a dim vermillon stub. Trend arrow sits in the top-right corner (the
/// arrow carries the colour).
struct HabitBarChart: View {
    let bars: [HabitBar]
    let mode: BarMode
    let trend: TrendDirection

    private var title: String { mode == .days ? "LAST 7 DAYS" : "BY WEEK" }
    private let maxHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(FudoFont.caption(13))
                    .tracking(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Spacer()
                TrendArrow(trend: trend, size: 12)
            }

            if bars.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(bars) { bar in
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(FudoColor.bgPrimary)
                            .frame(height: maxHeight)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(color(for: bar))
                            .frame(height: height(for: bar))
                    }
                    Text(bar.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FudoColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(AppAnimation.standard, value: bars)
    }

    private var barSpacing: CGFloat { mode == .days ? 8 : 6 }

    private func height(for bar: HabitBar) -> CGFloat {
        if bar.isMissed { return maxHeight * 0.20 }
        if bar.isToday && bar.fill == 0 { return maxHeight * 0.45 }   // in-progress stub
        return maxHeight * max(0.20, CGFloat(bar.fill))
    }

    private func color(for bar: HabitBar) -> Color {
        if bar.isMissed { return FudoColor.accent.opacity(0.18) }
        if bar.isToday && bar.fill == 0 { return FudoColor.accent.opacity(0.40) }
        return FudoColor.accent
    }

    private var emptyState: some View {
        Text("No days logged yet in this window.")
            .font(FudoFont.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: maxHeight, alignment: .leading)
    }
}
