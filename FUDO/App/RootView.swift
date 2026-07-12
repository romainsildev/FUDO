import SwiftUI

/// Root routing: onboarding → paywall → tabs. Onboarding/paywall are covers (per conventions).
/// With current defaults (onboarding done, entitled) it lands on MainTabView.
/// Every scene activation runs the rollover (grace-period closures, decay) before routing.
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var cover: FudoCover?

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .onboarding: OnboardingPlaceholderView()
                case .paywall: PaywallPlaceholderView()
                default: EmptyView()
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        evaluateRoute()
    }

    private func evaluateRoute() {
        if !appState.hasCompletedOnboarding {
            cover = .onboarding
        } else if !appState.entitlementActive {
            cover = .paywall
        } else {
            cover = nil
        }
    }
}
