import SwiftUI

/// Root routing: onboarding → paywall → tabs.
///
/// The onboarding is the RENDERED ROOT while it is pending — never a presented
/// cover (device pass 2026-07-16: a fullScreenCover animates in even at launch,
/// so the funnel visibly rose from the bottom; the first frame must BE the
/// splash). The paywall stays a cover per conventions. Every scene activation
/// runs the rollover (grace-period closures, decay) before routing.
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState
    @State private var flags: OnboardingFlags
    @State private var cover: FudoCover?

    init() {
        // Route BEFORE the first frame: the flags read is synchronous, so the
        // onboarding-vs-Home decision never waits for onAppear.
        let flags = OnboardingFlags()
        _flags = State(initialValue: flags)
        let state = AppState()
        state.hasCompletedOnboarding = flags.isFullyDone
        _appState = State(initialValue: state)
    }

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                mainRoot
            } else {
                OnboardingFlowView(store: gameStore, flags: flags, onFinished: refresh)
            }
        }
        .preferredColorScheme(.dark)
        // No animation at launch (first render is already the right root); the
        // mid-session swaps — funnel finished, DEBUG replay — cross-fade instead
        // of sliding, matching the funnel's own grammar.
        .animation(AppAnimation.standard, value: appState.hasCompletedOnboarding)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        // The DEBUG "Replay onboarding" flips this from inside the app: re-route
        // now rather than wait for the next scene activation.
        .onChange(of: appState.hasCompletedOnboarding) { _, _ in evaluateRoute() }
    }

    private var mainRoot: some View {
        MainTabView()
            .environment(appState)
            // fullScreenCover PRESENTS asynchronously (an animated transaction):
            // the shield is the opaque floor for that gap — gone the instant the
            // cover binding drops, so the dismissal still reveals Home normally.
            .overlay {
                if cover != nil {
                    RouteShieldView()
                }
            }
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .paywall:
                    PaywallPlaceholderView()   // trial-expired path — Session 6
                default:
                    EmptyView()
                }
            }
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

    /// The paywall is the only remaining cover — the onboarding routes at the
    /// root level, off `hasCompletedOnboarding` alone.
    private func evaluateRoute() {
        if appState.hasCompletedOnboarding && !appState.entitlementActive {
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
