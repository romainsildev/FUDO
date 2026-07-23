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
    var complianceLine: String? { selectedPlan?.complianceLine }
    /// The trial timeline only tells the truth for a plan that HAS a trial.
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
        }
    }

    #if DEBUG
    /// The sandbox is dead until the banking paperwork clears — this renders the
    /// full UI with the dashboard's real price points so the screen can be tuned
    /// on device. Purchasing a mock fails honestly; use the DEBUG Pro override
    /// to simulate the unlock.
    func useMockPlans() {
        plans = [.mockWeekly, .mockAnnual]
        loadState = .loaded
        purchaseState = .idle
    }
    #endif

    func select(_ kind: PaywallPlan.Kind) {
        guard !isBusy else { return }
        selectedKind = kind
        // A stale failure message about the OTHER plan shouldn't shame this one.
        if case .failed = purchaseState { purchaseState = .idle }
    }

    func purchaseSelected() async {
        guard canPurchase, let plan = selectedPlan, let entitlements else { return }
        purchaseState = .purchasing
        switch await entitlements.purchase(plan) {
        case .success:
            finishUnlocked()
        case .cancelled:
            // He stayed on the fence — no guilt copy, no error, back to idle.
            purchaseState = .idle
        case .failed(let message):
            purchaseState = .failed(message)
        }
    }

    func restore() async {
        guard !isBusy, let entitlements else { return }
        purchaseState = .restoring
        switch await entitlements.restore() {
        case .restored:
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
