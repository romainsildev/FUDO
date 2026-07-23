import Foundation
import Testing
@testable import FUDO

/// Pure display-model math — no container, no RevenueCat, no MainActor.
struct PaywallPlanTests {
    // MARK: - Savings badge (computed, never hardcoded — D4)

    @Test func savingsMatchTheLiveDashboardPrices() {
        // fudo_weekly_599 ($5.99) vs fudo_annual_4399 ($43.99):
        // 52 weeks = $311.48 → annual is ~14% of that → SAVE 86%.
        let percent = PaywallPlan.savingsPercent(
            weekly: Decimal(string: "5.99") ?? 0,
            annual: Decimal(string: "43.99") ?? 0)
        #expect(percent == 86)
    }

    @Test func noBadgeWhenAnnualIsNotCheaperThanWeekly() {
        // 0.99 × 52 = 51.48 < 59.99 → the badge would be a lie → nil.
        let percent = PaywallPlan.savingsPercent(
            weekly: Decimal(string: "0.99") ?? 0,
            annual: Decimal(string: "59.99") ?? 0)
        #expect(percent == nil)
    }

    @Test func noBadgeOnDegeneratePrices() {
        #expect(PaywallPlan.savingsPercent(weekly: 0, annual: 43.99) == nil)
        #expect(PaywallPlan.savingsPercent(weekly: 5.99, annual: 0) == nil)
    }

    @Test func savingsRoundToTheNearestPercent() {
        // 10 × 52 = 520; annual 260 → exactly 50%.
        #expect(PaywallPlan.savingsPercent(weekly: 10, annual: 260) == 50)
    }

    // MARK: - CTA copy (plan-driven, honest)

    @Test func trialPlanDrivesTheTrialCTA() {
        #expect(PaywallPlan.mockWeekly.ctaTitle == "Start my 3-day free trial")
    }

    @Test func planWithoutTrialFallsBackToContinue() {
        #expect(PaywallPlan.mockAnnual.ctaTitle == "Continue")
    }

    // MARK: - Apple compliance line (full price + auto-renew, pre-purchase)

    @Test func complianceLineCarriesTrialThenPriceAndAutoRenew() {
        let line = PaywallPlan.mockWeekly.complianceLine
        #expect(line.contains("3-day free trial"))
        #expect(line.contains("$5.99/week"))
        #expect(line.contains("Auto-renews"))
    }

    @Test func complianceLineWithoutTrialStartsAtThePrice() {
        let line = PaywallPlan.mockAnnual.complianceLine
        #expect(!line.contains("free trial"))
        #expect(line.contains("$43.99/year"))
        #expect(line.contains("Auto-renews"))
    }
}
