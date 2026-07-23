import Foundation
import Observation

/// Where the paywall is shown from — decides the header story and the exits.
enum PaywallContext: Equatable {
    /// End of the funnel: the personal projection sells; success hands control
    /// back to the flow (`passPaywall()` → notifications → … → Home day 1).
    case onboarding(contract: ContractSnapshot?, endDate: Date)
    /// Trial expired without conversion: Home is replaced, local data kept.
    /// No close — there is no free zone to explore.
    case reactivation
}

/// State machine for the paywall screen. Every mandatory state exists (a dead
/// CTA on unloaded products is the Guideline 2.1 rejection): skeleton while
/// loading, offline failure with retry, purchase in flight, sober failure —
/// and a cancelled purchase returns to idle with zero guilt copy.
@MainActor
@Observable
final class PaywallViewModel {
    enum LoadState: Equatable {
        case loading, loaded, failed
    }

    enum PurchaseState: Equatable {
        case idle, purchasing, restoring
        case failed(String)
    }

    let context: PaywallContext
    private let entitlements: EntitlementStore?
    private let onFinished: () -> Void

    private(set) var loadState: LoadState = .loading
    private(set) var plans: [PaywallPlan] = []
    /// Annual pre-selected (PRD 03).
    private(set) var selectedKind: PaywallPlan.Kind = .annual
    private(set) var purchaseState: PurchaseState = .idle

    /// Analytics: the placement value + when the screen appeared (dwell time).
    private var analyticsViewedAt: Date?
    private var didTrackViewed = false

    /// `paywall_*` placement (plan §1.3): the funnel end vs. the trial-expired
    /// reactivation cover.
    var placement: String {
        switch context {
        case .onboarding: return "onboarding"
        case .reactivation: return "trial_expired"
        }
    }

    init(context: PaywallContext, entitlements: EntitlementStore?,
         onFinished: @escaping () -> Void) {
        self.context = context
        self.entitlements = entitlements
        self.onFinished = onFinished
    }

    // MARK: - Derived

    var selectedPlan: PaywallPlan? { plans.first { $0.kind == selectedKind } }
    var weeklyPlan: PaywallPlan? { plans.first { $0.kind == .weekly } }
    var annualPlan: PaywallPlan? { plans.first { $0.kind == .annual } }

    /// "SAVE N%" for the annual card — real prices only, nil hides the badge.
    var savingsPercent: Int? {
        guard let weekly = weeklyPlan, let annual = annualPlan else { return nil }
        return PaywallPlan.savingsPercent(weekly: weekly.rawPrice, annual: annual.rawPrice)
    }

    var ctaTitle: String { selectedPlan?.ctaTitle ?? "Continue" }
    /// The trial timeline (and the "No payment due now" line) only tell the
    /// truth for a plan that HAS a trial.
    var showsTrialTimeline: Bool { selectedPlan?.trialDays != nil }

    var isBusy: Bool { purchaseState == .purchasing || purchaseState == .restoring }
    var canPurchase: Bool { loadState == .loaded && selectedPlan != nil && !isBusy }

    var failureMessage: String? {
        if case .failed(let message) = purchaseState { return message }
        return nil
    }

    // MARK: - Actions

    func load() async {
        loadState = .loading
        purchaseState = .idle
        guard let entitlements else {
            loadState = .failed
            return
        }
        do {
            plans = try await entitlements.loadPlans()
            loadState = .loaded
        } catch {
            loadState = .failed
            // A dead CTA on unloaded products = rejection 2.1 + lost trials — a signal.
            Analytics.track(AnalyticsEvent.paywallProductsFailed, ["reason": Self.failureReason(error)])
        }
    }

    private static func failureReason(_ error: Error) -> String {
        switch error {
        case EntitlementStore.PlanLoadError.storeUnavailable: return "store_unavailable"
        case EntitlementStore.PlanLoadError.offeringMissing: return "offering_missing"
        default: return "error"
        }
    }

    #if DEBUG
    /// True after `useMockPlans()`: the CTA then SIMULATES the full success path
    /// (the sandbox is dead until the banking paperwork clears) — brief in-flight
    /// beat → DEBUG Pro override → the exact same `finishUnlocked()` as a real
    /// purchase. Makes paywall → Welcome → Home day 1 testable end-to-end.
    private(set) var isMockSession = false

    /// Renders the full UI with the dashboard's real price points so the screen
    /// can be tuned on device, and arms the simulated purchase path above.
    /// Honors the "trial already consumed" DEBUG override so the ineligible
    /// layout is testable without a receipt.
    func useMockPlans() {
        let trialConsumed = entitlements?.debugTrialConsumed == true
        plans = [trialConsumed ? PaywallPlan.mockWeekly.strippingTrial() : .mockWeekly,
                 .mockAnnual]
        loadState = .loaded
        purchaseState = .idle
        isMockSession = true
    }
    #endif

    /// Fired by the flow on appear (guarded once) + on the X (dwell + selection).
    func trackViewed() {
        guard !didTrackViewed else { return }
        didTrackViewed = true
        analyticsViewedAt = Date()
        Analytics.track(AnalyticsEvent.paywallViewed, ["placement": placement])
    }

    func trackDismissed() {
        let seconds = analyticsViewedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        Analytics.track(AnalyticsEvent.paywallDismissed,
                        ["placement": placement, "seconds_on_screen": seconds,
                         "plan_selected": selectedKind.rawValue])
    }

    func select(_ kind: PaywallPlan.Kind) {
        guard !isBusy else { return }
        Analytics.track(AnalyticsEvent.paywallPlanSelected, ["plan": kind.rawValue])
        selectedKind = kind
        // A stale failure message about the OTHER plan shouldn't shame this one.
        if case .failed = purchaseState { purchaseState = .idle }
    }

    func purchaseSelected() async {
        guard canPurchase, let plan = selectedPlan else { return }
        #if DEBUG
        if isMockSession {
            purchaseState = .purchasing
            try? await Task.sleep(for: .seconds(0.9))
            entitlements?.debugProOverride = true
            finishUnlocked()
            return
        }
        #endif
        guard let entitlements else { return }
        purchaseState = .purchasing
        switch await entitlements.purchase(plan) {
        case .success:
            trackPurchaseSuccess(plan)
            finishUnlocked()
        case .cancelled:
            // He stayed on the fence — no guilt copy, no error, back to idle.
            Analytics.track(AnalyticsEvent.purchaseFailed,
                            ["plan": plan.kind.rawValue, "reason": "cancelled"])
            purchaseState = .idle
        case .failed(let message):
            Analytics.track(AnalyticsEvent.purchaseFailed,
                            ["plan": plan.kind.rawValue, "reason": "error"])
            purchaseState = .failed(message)
        }
    }

    /// A trial plan starts a trial; a no-trial plan is a direct purchase. The
    /// trial→paid conversion is RevenueCat's source of truth (plan §1.3), not
    /// emitted here — so `is_trial_conversion` is always false at purchase time.
    private func trackPurchaseSuccess(_ plan: PaywallPlan) {
        let priceUSD = NSDecimalNumber(decimal: plan.rawPrice).doubleValue
        if let trialDays = plan.trialDays {
            Analytics.track(AnalyticsEvent.trialStarted,
                            ["plan": plan.kind.rawValue, "price_usd": priceUSD,
                             "trial_days": trialDays])
        } else {
            Analytics.track(AnalyticsEvent.purchaseCompleted,
                            ["plan": plan.kind.rawValue, "price_usd": priceUSD,
                             "is_trial_conversion": false])
        }
    }

    func restore() async {
        guard !isBusy, let entitlements else { return }
        purchaseState = .restoring
        switch await entitlements.restore() {
        case .restored:
            Analytics.track(AnalyticsEvent.purchaseRestored)
            finishUnlocked()
        case .nothingToRestore:
            purchaseState = .failed("No previous purchase found on this Apple ID.")
        case .failed(let message):
            purchaseState = .failed(message)
        }
    }

    private func finishUnlocked() {
        purchaseState = .idle
        Haptics.success()
        // S9 wires the real D-1 trial reminder; the hook point exists now so the
        // success path never changes shape.
        NotificationService.scheduleTrialEndingReminderStub()
        onFinished()
    }
}
