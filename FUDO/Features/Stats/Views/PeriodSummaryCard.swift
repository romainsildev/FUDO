import SwiftUI

/// The period summary hero (Stats FINAL, 2026-07-24): the completion % blown up on the
/// left, checks + best-day stacked small on the right, and a "▲ +6% vs last week" delta
/// pinned top-right. All cream (2026-07-23): a completion number is an achievement, never
/// an alarm — the only green/red on this card is the delta arrow, which carries its own.
struct PeriodSummaryCard: View {
    let summary: PeriodSummary
    let delta: Int?
    let period: StatsPeriod

    private var periodLabel: String { period.menuLabel.uppercased() }

    /// "vs last week" (7d) / "vs prior 30 days" (30d). Empty for `.challenge` (delta nil).
    private var deltaCaption: String {
        switch period {
        case .week:      "vs last week"
        case .month:     "vs prior 30 days"
        case .challenge: ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let delta, delta != 0 {
                deltaBadge(delta)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(summary.completionPercent)%")
                        .fudoFont(.metric(50))
                        .foregroundStyle(FudoColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("COMPLETION — \(periodLabel)")
                        .fudoFont(.label(11))
                        .kerning(1)
                        .foregroundStyle(FudoColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(FudoColor.border)
                    .frame(width: 1, height: 52)
                    .padding(.horizontal, FudoSpacing.cardPadding)

                VStack(alignment: .leading, spacing: 14) {
                    miniStat(value: "\(summary.totalChecks)", caption: "CHECKS")
                    miniStat(value: summary.bestDayLabel ?? "—", caption: "BEST DAY")
                }
                .frame(width: 96, alignment: .leading)
            }
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func miniStat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .fudoFont(.metric(20))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .fudoFont(.label(10))
                .kerning(1)
                .foregroundStyle(FudoColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption), \(value)")
    }

    private func deltaBadge(_ delta: Int) -> some View {
        let up = delta > 0
        return HStack(spacing: 4) {
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .fudoFont(.glyph(9, weight: .bold))
            Text("\(up ? "+" : "")\(delta)% \(deltaCaption)")
                .fudoFont(.caption(12, weight: .semibold))
        }
        .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(up ? "Up" : "Down") \(abs(delta)) percent \(deltaCaption)")
    }
}

#if DEBUG
#Preview("Period summary — hero") {
    let summary = PeriodSummary(completionPercent: 80, totalChecks: 28,
                                bestDayLabel: "FRI", closedDayCount: 6)
    return VStack(spacing: 16) {
        PeriodSummaryCard(summary: summary, delta: 6, period: .week)
        PeriodSummaryCard(summary: summary, delta: -4, period: .month)
        PeriodSummaryCard(summary: summary, delta: nil, period: .challenge)
    }
    .padding(FudoSpacing.screenMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}
#endif
