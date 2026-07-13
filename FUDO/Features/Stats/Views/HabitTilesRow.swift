import SwiftUI

/// The three habit-detail header tiles (frame 05b): completion % · current streak ·
/// total checks. Completion carries the vermillon accent; the rest stay cream.
struct HabitTilesRow: View {
    let completionPercent: Int
    let streak: Int
    let totalChecks: Int

    var body: some View {
        HStack(spacing: 0) {
            tile(value: "\(completionPercent)%", caption: "COMPLETION", accent: true)
            divider
            tile(value: "\(streak)", caption: "DAY STREAK", accent: false)
            divider
            tile(value: "\(totalChecks)", caption: "CHECKS", accent: false)
        }
        .padding(.vertical, FudoSpacing.cardPaddingMajor)
        .padding(.horizontal, FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func tile(value: String, caption: String, accent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                .foregroundStyle(accent ? FudoColor.accent : FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 11, weight: .semibold))
                .kerning(1)
                .foregroundStyle(FudoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption), \(value)")
    }

    private var divider: some View {
        Rectangle().fill(FudoColor.border).frame(width: 1, height: 40)
    }
}
