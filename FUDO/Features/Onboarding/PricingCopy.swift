import Foundation

/// Session 5 STUBS. Session 6 replaces every value with the RevenueCat
/// StoreProduct's localized price: Apple requires the real price and the
/// auto-renew mention on screen, and a hardcoded "$5.99" is wrong the moment a
/// user opens the app outside the US storefront. Never ship these as-is.
enum PricingCopy {
    static let hook = "Less than a kebab per month."
    static let detail = "3-day free trial, then $5.99/week or $43.99/year.\nCancel anytime."
}
