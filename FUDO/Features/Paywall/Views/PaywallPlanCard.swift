import SwiftUI

/// One selectable plan card. The PRICE is the hero of the card; the trial plan
/// carries a corner badge ("3 DAYS FREE", vermillon — the word FREE outweighs
/// the price, Cal AI pattern) and the annual keeps the computed green SAVE
/// badge (the acted recommendation exception).
struct PaywallPlanCard: View {
    enum BadgeStyle {
        /// Vermillon capsule, crème text — the trial hook.
        case trial
        /// Green capsule, ink text — the savings recommendation.
        case savings
    }

    let plan: PaywallPlan
    let isSelected: Bool
    let badgeText: String?
    let badgeStyle: BadgeStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                selectionDot

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.textPrimary)
                    subtitleView
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(plan.price)
                        .fudoFont(.stat(22))
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
                                  lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) { cornerBadge }
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standard, value: isSelected)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "FREE for 3 days" carries the trial card; the annual talks per-month.
    @ViewBuilder
    private var subtitleView: some View {
        if let trialDays = plan.trialDays {
            Text("FREE for \(trialDays) days")
                .fudoFont(.body(14, weight: .semibold))
                .foregroundStyle(FudoColor.textPrimary)
        } else if let perMonth = plan.perMonthPrice {
            Text("\(perMonth) per month")
                .fudoFont(.caption())
                .foregroundStyle(FudoColor.textSecondary)
        } else {
            // No trial to promise (intro consumed) → the price stands alone.
            Text("Billed every \(plan.periodUnit)")
                .fudoFont(.caption())
                .foregroundStyle(FudoColor.textSecondary)
        }
    }

    /// Rides the card's top edge (Cal AI pattern) — the parent stack leaves the
    /// headroom, no clipping container above.
    @ViewBuilder
    private var cornerBadge: some View {
        if let badgeText {
            Text(badgeText)
                .fudoFont(.label(10, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(badgeStyle == .trial ? FudoColor.textPrimary : FudoColor.bgPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(badgeStyle == .trial ? FudoColor.accent : FudoColor.positive)
                }
                .offset(x: -14, y: -9)
        }
    }

    private var selectionDot: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? FudoColor.accent : FudoColor.border, lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(FudoColor.accent)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = [plan.title, "\(plan.price) per \(plan.periodUnit)"]
        if let trialDays = plan.trialDays { parts.append("free for \(trialDays) days") }
        if let badgeText { parts.append(badgeText) }
        return parts.joined(separator: ", ")
    }
}
