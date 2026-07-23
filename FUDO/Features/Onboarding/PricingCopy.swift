import Foundation

/// Paywall-only copy (Romain, OB 17 v2: no price anywhere before the paywall).
/// Prices NEVER live here — the paywall reads the RevenueCat StoreProduct's
/// localized strings, because Apple requires the real storefront price on
/// screen and a hardcoded "$5.99" is wrong outside the US storefront.
enum PricingCopy {
    /// The kebab line — small, under the plan cards (PRD 03).
    static let hook = "…less than one kebab a month."
}
