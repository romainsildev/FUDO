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
    // Optional on purpose: previews and the test shell never configure RevenueCat.
    @Environment(EntitlementStore.self) private var entitlementStore: EntitlementStore?
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
        // Entitlement changes land live from the RC stream (purchase, expiry,
        // restore, DEBUG override) — reflected without a relaunch.
        .onChange(of: entitlementStore?.isPro) { _, _ in syncEntitlement() }
        .onChange(of: entitlementStore?.isResolved) { _, _ in syncEntitlement() }
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
                    // Trial expired without conversion: Home replaced, local data
                    // kept, no close — purchase/restore flips isPro and the cover
                    // falls on its own.
                    PaywallView(context: .reactivation, onFinished: syncEntitlement)
                default:
                    EmptyView()
                }
            }
            // Rank-up celebration — presented above the tabs from the store's
            // high-water mark (D6), so it fires whether the rank was crossed by a
            // live check or a rollover closure, on any tab. Bound to the store
            // directly: the item re-evaluates every render, so a mark set at launch
            // (before this appeared) still presents — an onChange would miss it.
            .fullScreenCover(item: rankUpBinding) { presentation in
                RankUpCoverView(newRank: presentation.rank, store: gameStore) {
                    _ = gameStore.consumeRankUp()
                }
                .preferredColorScheme(.dark)
            }
    }

    /// Drains `pendingRankUp` into a presentation; dismissing consumes the mark so
    /// the same rank never re-celebrates.
    private var rankUpBinding: Binding<RankUpPresentation?> {
        Binding(
            get: { gameStore.pendingRankUp.map { RankUpPresentation(rank: $0) } },
            set: { newValue in
                if newValue == nil { _ = gameStore.consumeRankUp() }
            }
        )
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        // The HOLD-LOCK: "onboarding completed" is not enough — the post-paywall
        // trio must be finished too, or a kill at OB 19 would drop him into an app
        // with no reminder, no dojo, no widget pitch.
        appState.hasCompletedOnboarding = flags.isFullyDone
        syncEntitlement()
    }

    /// Mirror the entitlement into routing. Unresolved reads as PRO: a paying
    /// user must never see the paywall flash while the RC cache loads (it
    /// resolves within the first frames, offline included) — an expired user
    /// gets the cover one beat later instead, the acceptable side of that trade.
    private func syncEntitlement() {
        appState.entitlementActive = entitlementStore.map { $0.isResolved ? $0.isPro : true } ?? true
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
