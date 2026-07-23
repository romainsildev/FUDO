import Foundation

/// App-wide configuration — the ONE home for third-party keys and cross-feature
/// URLs (a public SDK key is fine client-side by design; the same literal
/// scattered across features is not). Gameplay constants do NOT live here —
/// they stay in `Core/Game/GameConfig.swift`.
enum AppConfig {
    // MARK: - RevenueCat (PRD 03)

    /// Public SDK key — safe to ship in the binary.
    static let revenueCatAPIKey = "appl_eFsVYidtJZHswTKOaKxACpTziSK"
    /// The one entitlement every product unlocks (dashboard: "pro").
    static let proEntitlementID = "pro"
    /// Offering "Main paywall" — verified live 2026-07-22: `$rc_weekly` →
    /// fudo_weekly_599, `$rc_annual` → fudo_annual_4399.
    static let defaultOfferingID = "default"

    // MARK: - PostHog (analytics, ANALYTICS-PLAN.md)

    /// Public project key — safe to ship. EU host is mandatory here (GDPR, plan §4).
    static let postHogAPIKey = "phc_AGWxa8wwv8N4hLddobbKmvFMQdqgRjGosx2nz5uQLFTt"
    /// Official EU ingestion domain (the dashboard hands out `eu.i.posthog.com`;
    /// the bare `eu.posthog.com` still redirects but is legacy).
    static let postHogHost = "https://eu.i.posthog.com"

    // MARK: - Legal
    // Settings AND the paywall footer link these (both mandatory for review).

    static let privacyURL = URL(string: "https://u8492529422-web.github.io/fudo-legal/privacy")!
    static let termsURL = URL(string: "https://u8492529422-web.github.io/fudo-legal/terms")!
}
