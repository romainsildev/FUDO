import Foundation
import Observation
import RevenueCat

/// The ONE seam between RevenueCat and the app (PRD 03). Owns every RC object —
/// views and view models only ever see `PaywallPlan` display models and plain
/// outcomes, so previews and unit tests never touch the SDK.
///
/// `isPro` mirrors the "pro" entitlement straight from the SDK's CustomerInfo
/// stream: the first emission is RevenueCat's local cache (instant, works
/// offline), then live updates follow — purchase, expiration and restore all
/// land here without a relaunch. Routing (RootView) treats "unresolved yet" as
/// pro, so a paying user never sees the paywall flash at launch.
@MainActor
@Observable
final class EntitlementStore {
    /// Raw SDK truth — kept separate so the DEBUG override never contaminates it.
    private(set) var isProLive = false
    /// True once the first CustomerInfo (cache or network) has been applied.
    private(set) var isResolved = false

    /// Was the last ACTIVE pro period the free trial? Remembered while active so
    /// `subscription_expired.had_trial` can be reported once the entitlement drops
    /// (an expired entitlement no longer reports its own period). Analytics only.
    private var lastActiveWasTrial = false

    /// RC packages stay HERE, keyed by plan kind — `PaywallPlan` is RC-free.
    private var packages: [PaywallPlan.Kind: Package] = [:]
    private var listenTask: Task<Void, Never>?

    /// What routing and gating read. The DEBUG override wins when set (the
    /// sandbox is unusable until the banking paperwork clears — this is the
    /// device test path for both sides of the gate).
    var isPro: Bool {
        #if DEBUG
        if let debugProOverride { return debugProOverride }
        #endif
        return isProLive
    }

    #if DEBUG
    /// nil = follow the SDK · true = force pro · false = force free.
    /// Stored (not computed) so @Observable tracks it; persisted for relaunches.
    var debugProOverride: Bool? = UserDefaults.standard.object(forKey: "debug.proOverride") as? Bool {
        didSet {
            if let debugProOverride {
                UserDefaults.standard.set(debugProOverride, forKey: "debug.proOverride")
            } else {
                UserDefaults.standard.removeObject(forKey: "debug.proOverride")
            }
        }
    }

    /// Simulates a user whose intro offer is already consumed: every trial
    /// promise drops off the paywall (real plans AND mocks). Persisted.
    var debugTrialConsumed: Bool = UserDefaults.standard.bool(forKey: "debug.trialConsumed") {
        didSet { UserDefaults.standard.set(debugTrialConsumed, forKey: "debug.trialConsumed") }
    }
    #endif

    // MARK: - Lifecycle

    /// Begin mirroring the SDK. Idempotent, and a silent no-op when Purchases
    /// isn't configured (previews, unit tests — FUDOApp's shell guard skips
    /// `Purchases.configure` there).
    func start() {
        guard Purchases.isConfigured, listenTask == nil else { return }
        listenTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.apply(info)
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        let wasResolved = isResolved
        let wasPro = isProLive
        let entitlement = info.entitlements[AppConfig.proEntitlementID]
        let nowPro = entitlement?.isActive == true
        isProLive = nowPro
        isResolved = true
        // Churn (plan §1.7): the pro entitlement was active and is now gone.
        if wasResolved, wasPro, !nowPro {
            Analytics.track(AnalyticsEvent.subscriptionExpired, ["had_trial": lastActiveWasTrial])
        }
        if nowPro { lastActiveWasTrial = entitlement?.periodType == .trial }
    }

    // MARK: - Offering → plans

    enum PlanLoadError: Error {
        case storeUnavailable
        case offeringMissing
    }

    /// Fetch the "default" offering and map its weekly + annual packages to pure
    /// display models. Throws so the paywall can show its mandatory retry state
    /// (a dead CTA on unloaded products is the Guideline 2.1 rejection).
    func loadPlans() async throws -> [PaywallPlan] {
        guard Purchases.isConfigured else { throw PlanLoadError.storeUnavailable }
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: AppConfig.defaultOfferingID)
                ?? offerings.current else {
            throw PlanLoadError.offeringMissing
        }
        let weekly = offering.weekly ?? offering.availablePackages.first { $0.packageType == .weekly }
        let annual = offering.annual ?? offering.availablePackages.first { $0.packageType == .annual }
        guard let weekly, let annual else { throw PlanLoadError.offeringMissing }
        packages = [.weekly: weekly, .annual: annual]
        let eligible = await trialEligibleIDs(for: [weekly.storeProduct, annual.storeProduct])
        return [plan(from: weekly, kind: .weekly, trialEligible: eligible),
                plan(from: annual, kind: .annual, trialEligible: eligible)]
    }

    /// Product ids allowed to PROMISE their intro offer. Apple bills an
    /// ineligible user immediately — so an explicit `.ineligible` from the SDK
    /// strips every trial promise off the screen (badge, timeline, CTA and
    /// recap all follow the plan's `trialDays`). `.unknown` stays optimistic:
    /// no receipt usually just means a brand-new user.
    private func trialEligibleIDs(for products: [StoreProduct]) async -> Set<String> {
        #if DEBUG
        if debugTrialConsumed { return [] }
        #endif
        let withIntro = products.filter { $0.introductoryDiscount != nil }
        guard !withIntro.isEmpty else { return [] }
        let statuses = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: withIntro.map(\.productIdentifier))
        return Set(withIntro.map(\.productIdentifier).filter { id in
            statuses[id]?.status != .ineligible
        })
    }

    private func plan(from package: Package, kind: PaywallPlan.Kind,
                      trialEligible: Set<String>) -> PaywallPlan {
        let product = package.storeProduct
        let allowsTrial = trialEligible.contains(product.productIdentifier)
        return PaywallPlan(
            kind: kind,
            price: product.localizedPriceString,
            rawPrice: product.price,
            trialDays: allowsTrial ? trialDays(of: product) : nil,
            perMonthPrice: perMonthPrice(of: product))
    }

    /// Days of free trial read off the intro offer — nil when the product bills
    /// from day one. The CTA and the timeline both derive from this, so a plan
    /// without a configured trial can never promise one.
    private func trialDays(of product: StoreProduct) -> Int? {
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        }
    }

    private func perMonthPrice(of product: StoreProduct) -> String? {
        guard let perMonth = product.pricePerMonth,
              let formatter = product.priceFormatter else { return nil }
        return formatter.string(from: perMonth)
    }

    // MARK: - Purchase / restore

    enum PurchaseOutcome: Equatable {
        case success
        case cancelled
        case failed(String)
    }

    func purchase(_ plan: PaywallPlan) async -> PurchaseOutcome {
        guard Purchases.isConfigured, let package = packages[plan.kind] else {
            return .failed("The store isn't reachable right now. Try again.")
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            return isProLive
                ? .success
                : .failed("The purchase went through but nothing unlocked. Tap Restore purchases.")
        } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    enum RestoreOutcome: Equatable {
        case restored
        case nothingToRestore
        case failed(String)
    }

    func restore() async -> RestoreOutcome {
        guard Purchases.isConfigured else {
            return .failed("The store isn't reachable right now. Try again.")
        }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return isProLive ? .restored : .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
