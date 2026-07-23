import SwiftUI

/// Layout constants specific to the paywall (PRD 03) — deliberately NOT in
/// FudoSpacing: the 65 pt CTA is a conversion-screen exception to the app-wide
/// 56, and stays contained here.
enum PaywallMetrics {
    static let ctaHeight: CGFloat = 65
    /// The close affordance appears only after the pitch had its beat.
    static let closeDelay: TimeInterval = 3
    /// Generous on purpose — the one-pager must breathe, not stack.
    static let sectionSpacing: CGFloat = 32
}

/// Thin environment reader (same shim pattern as SettingsView): hands the
/// EntitlementStore to the screen, which needs it at init for its view model.
struct PaywallView: View {
    @Environment(EntitlementStore.self) private var entitlements: EntitlementStore?

    let context: PaywallContext
    let onFinished: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        PaywallScreen(context: context, entitlements: entitlements,
                      onFinished: onFinished, onClose: onClose)
    }
}

/// The real paywall — one-page bullet flow, never a comparison table: personal
/// projection, trial timeline, two plans, kebab line, compliance, links.
/// Every mandatory state exists: skeleton while products load, offline failure
/// with retry, purchase spinner, sober failure, silent cancel.
struct PaywallScreen: View {
    @State private var viewModel: PaywallViewModel
    private let onClose: (() -> Void)?
    private let entitlements: EntitlementStore?

    @State private var closeVisible = false
    @State private var safariLink: SafariLink?

    init(context: PaywallContext, entitlements: EntitlementStore?,
         onFinished: @escaping () -> Void, onClose: (() -> Void)?) {
        _viewModel = State(initialValue: PaywallViewModel(
            context: context, entitlements: entitlements, onFinished: onFinished))
        self.onClose = onClose
        self.entitlements = entitlements
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PaywallMetrics.sectionSpacing) {
                PaywallHeaderView(context: viewModel.context)
                    .padding(.top, 4)

                PaywallBulletsView()

                timelineSection

                planSection

                PaywallFooterView(
                    isRestoring: viewModel.purchaseState == .restoring,
                    onRestore: { Task { await viewModel.restore() } },
                    onShowTerms: { safariLink = SafariLink(url: AppConfig.termsURL) },
                    onShowPrivacy: { safariLink = SafariLink(url: AppConfig.privacyURL) })

                #if DEBUG
                debugOverrideEscape
                #endif
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.contentBottom)
        }
        .scrollIndicators(.hidden)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { ctaBlock }
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await viewModel.load() }
        .task { await revealCloseAfterDelay() }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        // NO animation on loadState: the swap must SNAP (a crossfade dips both
        // states to translucent for a beat — read as a blank frame on device).
        // The skeleton is the initial state, rendered from the very first frame.
        .animation(AppAnimation.standard, value: viewModel.showsTrialTimeline)
        .preferredColorScheme(.dark)
    }

    // MARK: - Timeline (honest per selection)

    @ViewBuilder
    private var timelineSection: some View {
        if viewModel.showsTrialTimeline, let days = viewModel.selectedPlan?.trialDays {
            TrialTimelineView(trialDays: days)
        } else if viewModel.loadState == .loaded, let plan = viewModel.selectedPlan {
            // No trial on the selected plan → no trial story. One true line instead.
            Text("Billed today · renews every \(plan.periodUnit) · cancel anytime")
                .fudoFont(.caption())
                .foregroundStyle(FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Plans (loading / failed / loaded)

    @ViewBuilder
    private var planSection: some View {
        switch viewModel.loadState {
        case .loading:
            PaywallSkeletonView()
        case .failed:
            loadFailure
        case .loaded:
            VStack(spacing: 14) {
                ForEach(viewModel.plans) { plan in
                    PaywallPlanCard(
                        plan: plan,
                        isSelected: viewModel.selectedKind == plan.kind,
                        badgeText: badgeText(for: plan),
                        badgeStyle: plan.kind == .annual ? .savings : .trial,
                        action: { viewModel.select(plan.kind) })
                }
                Text(PricingCopy.hook)
                    .fudoFont(.caption())
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 2)
            }
            // Headroom for the corner badges riding the cards' top edge.
            .padding(.top, 6)
        }
    }

    /// ONE corner badge per card, never two fighting (trial lives on BOTH plans
    /// since conflit #25, so it no longer differentiates): the annual's corner
    /// carries its headline argument — the computed "SAVE 86%" — while its trial
    /// speaks through the subtitle, the timeline, the CTA and the recap. The
    /// weekly keeps the vermillon trial hook.
    private func badgeText(for plan: PaywallPlan) -> String? {
        if plan.kind == .annual {
            return viewModel.savingsPercent.map { "SAVE \($0)%" }
        }
        return plan.trialDays.map { "\($0) DAYS FREE" }
    }

    /// Offline / store failure — message + Retry, never a dead end (2.1).
    private var loadFailure: some View {
        VStack(spacing: 14) {
            Text("Couldn't reach the App Store.")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
            Text("Check your connection and try again.")
                .fudoFont(.caption())
                .foregroundStyle(FudoColor.textSecondary)
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
                    .fudoFont(.headline(15))
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.horizontal, 28)
                    .frame(height: 44)
                    .background { Capsule().fill(FudoColor.bgCard) }
                    .overlay { Capsule().strokeBorder(FudoColor.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)

            #if DEBUG
            // Sandbox is blocked (banking) — this renders the full UI on device.
            Button {
                viewModel.useMockPlans()
            } label: {
                Text("Use mock products (DEBUG)")
                    .fudoFont(.caption())
                    .foregroundStyle(FudoColor.textSecondary)
                    .underline()
            }
            .buttonStyle(.plain)
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - CTA block (compliance + button + reassurance)

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            if let message = viewModel.failureMessage {
                // Factual, never guilt-tripping — and we stay right here.
                Text(message)
                    .fudoFont(.caption())
                    .foregroundStyle(FudoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Cal AI's #1 trust line — only when the selected plan HAS a trial.
            if viewModel.showsTrialTimeline {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .fudoFont(.glyph(12, weight: .semibold))
                    Text("No payment due now")
                        .fudoFont(.headline(13))
                }
                .foregroundStyle(FudoColor.textPrimary)
            }

            Button {
                Task { await viewModel.purchaseSelected() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.purchaseState == .purchasing {
                        ProgressView()
                            .tint(FudoColor.textPrimary)
                    } else {
                        Text(viewModel.ctaTitle)
                            .fudoFont(.headline())
                        Image(systemName: "chevron.right")
                            .fudoFont(.glyph(14, weight: .semibold))
                    }
                }
                .foregroundStyle(ctaLooksLive ? FudoColor.textPrimary : FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: PaywallMetrics.ctaHeight)
                .background { Capsule().fill(ctaLooksLive ? FudoColor.accent : FudoColor.bgCard) }
                .overlay {
                    if !ctaLooksLive {
                        Capsule().strokeBorder(FudoColor.border, lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canPurchase)

            // Compact price recap + the Apple-required renewal notice — two short
            // centered lines, never a wall of text.
            if viewModel.loadState == .loaded, let plan = viewModel.selectedPlan {
                VStack(spacing: 2) {
                    Text(plan.priceRecapLine)
                    Text(PaywallPlan.autoRenewNotice)
                }
                .fudoFont(.caption(11))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background {
            // Soft floor so scrolled content never fights the CTA.
            LinearGradient(
                colors: [FudoColor.bgPrimary.opacity(0), FudoColor.bgPrimary],
                startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
        }
        .animation(AppAnimation.standard, value: viewModel.purchaseState)
    }

    /// Vermillon only when tapping it can do something (or a purchase is in
    /// flight) — a dead-looking CTA on unloaded products is the honest state.
    private var ctaLooksLive: Bool {
        viewModel.canPurchase || viewModel.purchaseState == .purchasing
    }

    // MARK: - Close (funnel only, after the 3 s beat)

    @ViewBuilder
    private var closeButton: some View {
        if let onClose, closeVisible {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .fudoFont(.glyph(13, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(FudoColor.bgCard) }
                    .overlay { Circle().strokeBorder(FudoColor.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .padding(.trailing, FudoSpacing.screenMargin)
            .padding(.top, 8)
            .transition(.opacity)
            .accessibilityLabel("Close the paywall")
        }
    }

    private func revealCloseAfterDelay() async {
        guard onClose != nil else { return }
        try? await Task.sleep(for: .seconds(PaywallMetrics.closeDelay))
        guard !Task.isCancelled else { return }
        withAnimation(AppAnimation.standard) { closeVisible = true }
    }

    #if DEBUG
    /// The Free override raises this cover over the WHOLE app — Settings
    /// included — so the way back has to live on the paywall itself.
    @ViewBuilder
    private var debugOverrideEscape: some View {
        if viewModel.context == .reactivation, let entitlements,
           entitlements.debugProOverride != nil {
            Button {
                entitlements.debugProOverride = nil
            } label: {
                Text("DEBUG · Reset entitlement override")
                    .fudoFont(.caption(11))
                    .foregroundStyle(FudoColor.textSecondary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }
    #endif
}

#if DEBUG
#Preview("Paywall — reactivation (failure → mock button)") {
    PaywallScreen(context: .reactivation, entitlements: nil,
                  onFinished: {}, onClose: nil)
        .preferredColorScheme(.dark)
}
#endif
