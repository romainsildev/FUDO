import SwiftUI

/// Tiny 7-day recent-form sparkline for a habit row. A day is binary per habit, so
/// each bar is held (full vermillon) or missed (short, dead). Bars/rings stay
/// vermillon — the coloured signal lives on the neighbouring trend arrow, not here.
struct HabitSparkline: View {
    let days: [Bool]          // most recent last
    var height: CGFloat = 24
    var barWidth: CGFloat = 3.5

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, held in
                Capsule()
                    .fill(held ? FudoColor.accent : FudoColor.accent.opacity(0.22))
                    .frame(width: barWidth, height: held ? height : height * 0.42)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
