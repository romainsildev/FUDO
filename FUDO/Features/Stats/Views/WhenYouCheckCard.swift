import SwiftUI

/// "When you check" (Habit FINAL, 2026-07-23): the habit's hour-of-day signature —
/// a gold-rimmed insight card with the peak window spelled out and a six-bucket
/// histogram (6a → 9p). Gold marks the peak; the rest stays cream. Hidden by the
/// parent before the first check (peakLine == nil).
struct WhenYouCheckCard: View {
    let buckets: [HourBucket]
    let peakLine: String

    private let plotHeight: CGFloat = 54

    private var maxCount: Int { max(buckets.map(\.count).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .fudoFont(.label(10, weight: .bold))
                Text("WHEN YOU CHECK")
                    .fudoFont(.label(11, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(FudoColor.celebrationGold)

            Text(peakLine)
                .fudoFont(.headline(15))
                .foregroundStyle(FudoColor.textPrimary)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(barColor(for: bucket))
                            .frame(height: barHeight(for: bucket))
                            .frame(maxWidth: .infinity)
                            .frame(height: plotHeight, alignment: .bottom)
                        Text(bucket.label)
                            .fudoFont(.label(9))
                            .foregroundStyle(bucket.isPeak ? FudoColor.celebrationGold
                                                           : FudoColor.textSecondary.opacity(0.8))
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(FudoSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.celebrationGold.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("When you check: \(peakLine)")
    }

    private func barHeight(for bucket: HourBucket) -> CGFloat {
        guard bucket.count > 0 else { return 3 }
        return max(CGFloat(bucket.count) / CGFloat(maxCount) * plotHeight, 8)
    }

    private func barColor(for bucket: HourBucket) -> Color {
        if bucket.count == 0 { return Color.white.opacity(0.06) }
        if bucket.isPeak { return FudoColor.celebrationGold }
        return FudoColor.textPrimary.opacity(0.55)
    }
}
