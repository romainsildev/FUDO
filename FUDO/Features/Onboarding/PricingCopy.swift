import Foundation

/// Session 5 STUBS — PAYWALL-ONLY (Romain, OB 17 v2: no price anywhere before
/// the paywall; the kebab hook waits here for Session 6). Session 6 replaces
/// every value with the RevenueCat StoreProduct's localized price: Apple
/// requires the real price and the auto-renew mention on screen, and a
/// hardcoded "$5.99" is wrong the moment a user opens the app outside the US
/// storefront. Never ship these as-is.
enum PricingCopy {
    static let hook = "Less than a kebab per month."
    static let detail = "3-day free trial, then $5.99/week or $44.99/year.\nCancel anytime."
}
