import SwiftUI

/// Root routing: onboarding → paywall → tabs. Onboarding/paywall are covers (per conventions).
/// With current defaults (onboarding done, entitled) it lands on MainTabView.
/// Every scene activation runs the rollover (grace-period closures, decay) before routing.
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var flags = OnboardingFlags()
    @State private var cover: FudoCover?

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .onboarding:
                    OnboardingFlowView(store: gameStore, flags: flags, onFinished: refresh)
                case .paywall:
                    PaywallPlaceholderView()   // trial-expired path — Session 6
                default:
                    EmptyView()
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
            // The DEBUG "Replay onboarding" flips this from inside the app: re-route
            // now rather than wait for the next scene activation.
            .onChange(of: appState.hasCompletedOnboarding) { _, _ in evaluateRoute() }
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        // The HOLD-LOCK: "onboarding completed" is not enough — the post-paywall
        // trio must be finished too, or a kill at OB 19 would drop him into an app
        // with no reminder, no dojo, no widget pitch.
        appState.hasCompletedOnboarding = flags.isFullyDone
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
