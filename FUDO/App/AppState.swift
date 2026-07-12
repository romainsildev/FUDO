import SwiftUI
import Observation

/// Thin routing state ONLY. No game math, no persistence, no networking.
/// Real state plugs in behind these flags without AppState growing:
///  - GameStore (Session 1) assigns `hasActiveChallenge`.
///  - EntitlementStore (Session 6) assigns `entitlementActive`.
///  - Onboarding completion (later) assigns `hasCompletedOnboarding`.
@Observable final class AppState {
    var hasCompletedOnboarding = true   // SEAM (onboarding): default true until onboarding ships
    var entitlementActive = true        // SEAM (Session 6 EntitlementStore)
    var hasActiveChallenge = false      // SEAM (Session 1 GameStore)
    var selectedTab: AppTab = .today
}
