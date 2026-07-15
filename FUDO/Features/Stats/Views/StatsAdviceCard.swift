import SwiftUI

/// One-line, locally-generated advice (frame 05 / 05b). Faint vermillon wash so it
/// reads as a highlighted takeaway without breaking the ≤10 % accent budget. Reused by
/// the Stats tab (cross-habit) and the Habit detail (this habit).
struct StatsAdviceCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .fudoFont(.body(14, weight: .semibold))
                .foregroundStyle(FudoColor.accent)
                .padding(.top, 1)
            Text(text)
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(FudoSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.accent.opacity(0.08))
                .strokeBorder(FudoColor.accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityLabel("Advice: \(text)")
    }
}
