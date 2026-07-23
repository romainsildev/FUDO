import SwiftUI

/// Blinkist-pattern trial timeline — three beats, vertical, connected. Only
/// rendered when the SELECTED plan actually carries a trial (honesty over
/// pattern: a plan billing today never shows a trial story).
struct TrialTimelineView: View {
    let trialDays: Int

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
    }

    private var steps: [Step] {
        [
            Step(id: 0, icon: "lock.open.fill", title: "Today",
                 detail: "Full access. Your protocol starts now."),
            Step(id: 1, icon: "bell.badge.fill", title: "Day \(max(trialDays - 1, 1))",
                 detail: "We remind you by notification before billing."),
            Step(id: 2, icon: "creditcard.fill", title: "Day \(trialDays)",
                 detail: "Trial ends. Billing starts unless you cancelled."),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        iconCircle(step.icon)
                        if step.id < steps.count - 1 {
                            Rectangle()
                                .fill(FudoColor.border)
                                .frame(width: 1.5, height: 20)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .fudoFont(.headline(15))
                            .foregroundStyle(FudoColor.textPrimary)
                        Text(step.detail)
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                    .padding(.bottom, 12)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func iconCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .fudoFont(.glyph(14))
            .foregroundStyle(FudoColor.accent)
            .frame(width: 34, height: 34)
            .background { Circle().fill(FudoColor.bgPrimary) }
            .overlay { Circle().strokeBorder(FudoColor.border, lineWidth: 1) }
    }
}
