import SwiftUI

/// Root routing: onboarding → paywall → tabs. Onboarding/paywall are covers (per conventions).
/// With current defaults (onboarding done, entitled) it lands on MainTabView.
/// Every scene activation runs the rollover (grace-period closures, decay) before routing.
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var flags: OnboardingFlags
    @State private var cover: FudoCover?

    init() {
        // Route BEFORE the first frame: the flags read is synchronous, so the
        // onboarding-vs-Home decision never waits for onAppear.
        let flags = OnboardingFlags()
        _flags = State(initialValue: flags)
        _cover = State(initialValue: flags.isFullyDone ? nil : .onboarding)
    }

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            // fullScreenCover PRESENTS asynchronously (an animated transaction):
            // even a route decided at init leaves Home exposed under the slide-up.
            // The shield is the opaque floor for that gap — gone the instant the
            // cover binding drops, so the dismissal still reveals Home normally.
            .overlay {
                if cover != nil {
                    RouteShieldView()
                }
            }
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

/// Opaque floor under a pending cover — background + ensō, nothing else. It
/// lives well under a second (the cover's presentation), so it stays static:
/// any animation here would just flash.
private struct RouteShieldView: View {
    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            Image("enso-100")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
        }
    }
}
