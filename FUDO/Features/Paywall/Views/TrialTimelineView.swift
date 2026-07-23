import SwiftUI

/// Blinkist-pattern trial timeline: three beats on ONE continuous vermillon
/// spine (Cal AI does the same, orange→black — here the future beat fades:
/// billing only happens if he stays). Naked on the ink background so the screen
/// breathes. Only rendered when the SELECTED plan actually carries a trial —
/// a plan billing today never shows a trial story.
struct TrialTimelineView: View {
    let trialDays: Int

    private enum Metrics {
        static let circle: CGFloat = 36
        static let spineWidth: CGFloat = 3
        static let connector: CGFloat = 24
    }

    private struct Step {
        let icon: String
        let title: String
        let detail: String
        /// The billing beat — hasn't happened yet, so it renders dimmed.
        let isFuture: Bool
    }

    private var steps: [Step] {
        [
            Step(icon: "lock.open.fill", title: "Today",
                 detail: "Full access. Everything unlocked.", isFuture: false),
            Step(icon: "bell.badge.fill", title: "Day \(max(trialDays - 1, 1)) · Reminder",
                 detail: "We remind you before billing.", isFuture: false),
            Step(icon: "creditcard.fill", title: "Day \(trialDays) · Billing starts",
                 detail: "Cancel anytime before.", isFuture: true),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        circle(for: step)
                        if index < steps.count - 1 {
                            connector(fades: index == steps.count - 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .fudoFont(.headline(16))
                            .foregroundStyle(FudoColor.textPrimary)
                        Text(step.detail)
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func circle(for step: Step) -> some View {
        Image(systemName: step.icon)
            .fudoFont(.glyph(14))
            .foregroundStyle(step.isFuture ? FudoColor.textSecondary : FudoColor.textPrimary)
            .frame(width: Metrics.circle, height: Metrics.circle)
            .background {
                Circle().fill(step.isFuture ? FudoColor.bgCard : FudoColor.accentDeep)
            }
            .overlay {
                Circle().strokeBorder(
                    step.isFuture ? FudoColor.accent.opacity(0.35) : FudoColor.accent,
                    lineWidth: 1.5)
            }
    }

    /// The spine segment between two beats — continuous vermillon, fading into
    /// the future on its last stretch.
    @ViewBuilder
    private func connector(fades: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.spineWidth / 2)
        Group {
            if fades {
                shape.fill(LinearGradient(
                    colors: [FudoColor.accent, FudoColor.accent.opacity(0.2)],
                    startPoint: .top, endPoint: .bottom))
            } else {
                shape.fill(FudoColor.accent)
            }
        }
        .frame(width: Metrics.spineWidth, height: Metrics.connector)
    }
}
