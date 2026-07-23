import SwiftUI

/// One selectable plan card. Selection = vermillon border + filled dot; the
/// badge ("SAVE 86%", computed) rides the annual card — `positive` green, the
/// acted recommendation-badge exception (same family as the chip-60 liner).
struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                selectionDot

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .fudoFont(.headline())
                            .foregroundStyle(FudoColor.textPrimary)
                        if let badge {
                            Text(badge)
                                .fudoFont(.label(10, weight: .bold))
                                .kerning(0.5)
                                .foregroundStyle(FudoColor.bgPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background { Capsule().fill(FudoColor.positive) }
                        }
                    }
                    Text(subtitle)
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textSecondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .fudoFont(.stat(17))
                        .foregroundStyle(FudoColor.textPrimary)
                    Text("per \(plan.periodUnit)")
                        .fudoFont(.caption(11))
                        .foregroundStyle(FudoColor.textSecondary)
                }
            }
            .padding(FudoSpacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(isSelected ? FudoColor.accent : FudoColor.border,
                                  lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standard, value: isSelected)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Trial on the weekly, monthly equivalent on the annual — always true copy.
    private var subtitle: String {
        if let trialDays = plan.trialDays { return "\(trialDays)-day free trial" }
        if let perMonth = plan.perMonthPrice { return "\(perMonth) per month" }
        return "Billed once a \(plan.periodUnit)"
    }

    private var selectionDot: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? FudoColor.accent : FudoColor.border, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(FudoColor.accent)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = [plan.title, "\(plan.price) per \(plan.periodUnit)", subtitle]
        if let badge { parts.append(badge) }
        return parts.joined(separator: ", ")
    }
}
