import Foundation

/// Pure display model for one paywall plan — NO RevenueCat import, ever: the
/// SDK objects stay inside `EntitlementStore`, so previews and unit tests build
/// plans directly and the store swaps mocks in without the views knowing.
struct PaywallPlan: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case weekly, annual
    }

    let kind: Kind
    /// Localized by StoreKit for the user's storefront ("5,99 €"). Never hardcoded.
    let price: String
    /// The raw decimal behind `price`, for the savings math.
    let rawPrice: Decimal
    /// Days of free trial (intro offer) — nil when the plan bills immediately.
    let trialDays: Int?
    /// Localized monthly equivalent — shown on the annual card.
    let perMonthPrice: String?

    var id: String { kind.rawValue }

    /// Short names only (PRD 03) — never "Premium".
    var title: String {
        switch kind {
        case .weekly: return "Weekly"
        case .annual: return "Annual"
        }
    }

    /// "week" / "year" — the unit after the price.
    var periodUnit: String {
        switch kind {
        case .weekly: return "week"
        case .annual: return "year"
        }
    }

    /// CTA copy is plan-driven and honest: no trial on the product → no trial
    /// in the button. Never "Get Premium".
    var ctaTitle: String {
        if let trialDays { return "Start my \(trialDays)-day free trial" }
        return "Continue"
    }

    /// The Apple-required line: full price + auto-renew mention, visible on the
    /// screen BEFORE any purchase.
    var complianceLine: String {
        if let trialDays {
            return "\(trialDays)-day free trial, then \(price)/\(periodUnit). "
                + "Auto-renews until cancelled. Cancel anytime in Settings."
        }
        return "\(price)/\(periodUnit). Auto-renews until cancelled. Cancel anytime in Settings."
    }

    /// "SAVE 86%" — computed from the real prices, never hardcoded (doctrine D4:
    /// the badge must stay true if pricing ever changes). nil when there is
    /// nothing to save.
    static func savingsPercent(weekly: Decimal, annual: Decimal) -> Int? {
        guard weekly > 0, annual > 0 else { return nil }
        let yearlyAtWeekly = weekly * 52
        guard annual < yearlyAtWeekly else { return nil }
        let ratio = NSDecimalNumber(decimal: annual).doubleValue
            / NSDecimalNumber(decimal: yearlyAtWeekly).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent > 0 ? percent : nil
    }
}

#if DEBUG
extension PaywallPlan {
    /// Device/canvas stand-ins while the sandbox is blocked (no banking
    /// agreement = StoreKit resolves nothing). Prices mirror the live RC
    /// dashboard config (fudo_weekly_599 / fudo_annual_4399).
    static let mockWeekly = PaywallPlan(
        kind: .weekly, price: "$5.99", rawPrice: Decimal(string: "5.99") ?? 5.99,
        trialDays: 3, perMonthPrice: nil)
    static let mockAnnual = PaywallPlan(
        kind: .annual, price: "$43.99", rawPrice: Decimal(string: "43.99") ?? 43.99,
        trialDays: nil, perMonthPrice: "$3.67")
}
#endif
