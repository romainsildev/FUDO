import SwiftUI

/// The period summary (frame 05): three stats — completion %, checks done, best day —
/// split by hairline dividers. Completion carries the vermillon accent (a hero number);
/// the other two stay cream.
struct PeriodSummaryCard: View {
    let summary: PeriodSummary

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(summary.completionPercent)%", caption: "COMPLETION", accent: true)
            divider
            stat(value: "\(summary.totalChecks)", caption: "CHECKS DONE", accent: false)
            divider
            stat(value: summary.bestDayLabel ?? "—", caption: "BEST DAY", accent: false)
        }
        .padding(.vertical, FudoSpacing.cardPaddingMajor)
        .padding(.horizontal, FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func stat(value: String, caption: String, accent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .fudoFont(.metric(30))
                .foregroundStyle(accent ? FudoColor.accent : FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .fudoFont(.label(11))
                .kerning(1)
                .foregroundStyle(FudoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption), \(value)")
    }

    private var divider: some View {
        Rectangle()
            .fill(FudoColor.border)
            .frame(width: 1, height: 40)
    }
}
