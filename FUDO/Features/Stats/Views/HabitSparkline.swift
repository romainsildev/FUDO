import SwiftUI

/// Tiny 7-day recent-form sparkline for a habit row. Semantics repaired 2026-07-23:
/// held days are cream (success is warm, not vermillon mass-fill), a missed day is the
/// short dead red bar — the only red — and today-still-open stays neutral.
struct HabitSparkline: View {
    let days: [SparkDay]      // most recent last
    var height: CGFloat = 24
    var barWidth: CGFloat = 3.5

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Capsule()
                    .fill(color(for: day))
                    .frame(width: barWidth, height: day == .held ? height : height * 0.42)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func color(for day: SparkDay) -> Color {
        switch day {
        case .held:   return FudoColor.textPrimary.opacity(0.88)
        case .missed: return FudoColor.negative.opacity(0.75)
        case .open:   return FudoColor.textSecondary.opacity(0.25)
        }
    }
}
