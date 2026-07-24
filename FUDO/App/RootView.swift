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
    // Optional too: only the real app injects the router (previews/tests don't).
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState
    @State private var flags: OnboardingFlags
    @State private var cover: FudoCover?
    /// The end-of-challenge sequence (verdict → share → hook), then a pre-filled
    /// setup if a hook CTA is chosen. Local flow state, drained from the store's
    /// completion mark so it survives `activeChallenge` being nil'd at completion.
    @State private var completionFlow: CompletionFlowStep?
    /// Set from a rank-up notification tap (deep link) — presents the share card.
    @State private var deepLinkShare: ShareCardRequest?

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
        // A rank-up notification tapped while the app was already running: present
        // the share card. (Cold-launch taps are caught by `refresh()` on appear.)
        .onChange(of: router?.pendingDeepLink) { _, _ in handlePendingDeepLink() }
        // The DEBUG "Complete challenge" marks completion outside a scene refresh;
        // scene rollovers are covered by `refresh()`. Both funnel into the drain,
        // which no-ops once a flow is already showing.
        .onChange(of: gameStore.pendingChallengeCompletion?.id) { _, _ in drainCompletion() }
    }

    @ViewBuilder
    private func completionFlowContent(_ step: CompletionFlowStep) -> some View {
        switch step {
        case .verdict(let summary):
            ChallengeCompleteCoverView(
                summary: summary,
                onClose: { completionFlow = nil },
                onLaunch: { intent in completionFlow = .setup(intent) })
        case .setup(let intent):
            // Same standalone screen the Home CTA uses — pre-filled, attributed to
            // the post-challenge origin. A back or a successful launch drops the flow.
            ChallengeSetupStandaloneView(store: gameStore, intent: intent) {
                completionFlow = nil
            }
        }
    }

    /// Move the store's one-shot completion mark into the local flow. Consuming it
    /// immediately hands ownership to `completionFlow` (the summary is a value, it
    /// survives) and stops the rank-up cover from also firing for the same event.
    private func drainCompletion() {
        guard completionFlow == nil,
              let summary = gameStore.consumeChallengeCompletion() else { return }
        completionFlow = .verdict(summary)
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
            // End-of-challenge sequence — drained from the store's completion mark
            // (see `drainCompletion`). One cover whose content swaps verdict → setup
            // when a hook CTA is chosen, so there is no dismiss/re-present race.
            .fullScreenCover(item: $completionFlow) { step in
                completionFlowContent(step)
                    .preferredColorScheme(.dark)
                    .interactiveDismissDisabled(true)
            }
            // Deep-linked share card (rank-up notification tap). Separate from the
            // rank-up overlay below: the deep-link handler consumes the pending mark
            // first, so the two never contend for the same rank-up event.
            .shareCardPreview($deepLinkShare)
            // Rank-up celebration — a ROOT OVERLAY above the tabs (not a cover): it
            // plays over the current screen with Home darkened + blurred behind, the
            // context still visible. Driven by the store's high-water mark (D6) so it
            // fires on any tab whether the rank was crossed by a live check or a
            // rollover closure; `rankUpRank` reads the store every render, so a mark
            // set at launch still shows. Gated so the end-of-challenge sequence
            // subsumes a twin rank-up (S11).
            .overlay {
                if let rank = rankUpRank {
                    RankUpOverlayView(reachedRank: rank, store: gameStore) {
                        _ = gameStore.consumeRankUp()
                    }
                    .transition(.opacity)
                }
            }
            .animation(AppAnimation.standard, value: rankUpRank)
    }

    /// Drain a rank-up deep link into the share card. Consumes the in-memory rank-up
    /// mark first so the celebration cover doesn't ALSO fire for the same event, then
    /// clears the router so re-entry is a no-op.
    private func handlePendingDeepLink() {
        guard case .rankUpShare(let rank) = router?.pendingDeepLink else { return }
        _ = gameStore.consumeRankUp()
        deepLinkShare = ShareCardRequest(variant: .rankUp,
                                         data: ShareCardData.rankUp(to: rank, from: gameStore),
                                         origin: .rankUp)
        router?.pendingDeepLink = nil
    }

    /// The reached rank to celebrate, or nil. The challenge-complete sequence
    /// subsumes any rank-up crossed on the final closure (its beat 1 replays the
    /// climb), so suppress the overlay while a completion is pending or already on
    /// screen. Read every render (not via onChange) so a mark set at launch still
    /// shows; the overlay's Done button consumes the mark via `consumeRankUp()`.
    private var rankUpRank: Rank? {
        guard completionFlow == nil, gameStore.pendingChallengeCompletion == nil else { return nil }
        return gameStore.pendingRankUp
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        // A rollover that just finished the challenge left a completion mark — raise
        // the verdict sequence on this same activation (the mark is set inside the
        // rollover above).
        drainCompletion()
        // Foreground: fire `widget_detected` only when the installed families
        // changed (self-guarded, DEBUG no-op). Cheap async call, safe every wake.
        WidgetBridge.reportInstalledWidgetsIfChanged()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        // The HOLD-LOCK: "onboarding completed" is not enough — the post-paywall
        // trio must be finished too, or a kill at OB 19 would drop him into an app
        // with no reminder, no dojo, no widget pitch.
        appState.hasCompletedOnboarding = flags.isFullyDone
        syncEntitlement()
        // A tap that cold-launched the app set the deep link before this view could
        // observe it — drain it here on the first appear / every activation.
        handlePendingDeepLink()
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

/// The end-of-challenge flow, one presentation: the verdict sequence, then the
/// pre-filled setup if a hook CTA is chosen. Both cases ride the SAME cover so
/// the swap is a content change (no dismiss/re-present flicker between them).
enum CompletionFlowStep: Identifiable {
    case verdict(ChallengeCompletionSummary)
    case setup(ChallengeSetupIntent)

    var id: String {
        switch self {
        case .verdict(let summary): return "verdict-\(summary.id)"
        case .setup(let intent):    return "setup-\(intent.id)"
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
