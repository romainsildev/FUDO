import SwiftUI

/// The paywall's SLOT in the funnel (OnboardingStep.paywall) — S6 filled it.
/// Same `(contract:date:onContinue:)` signature as the S5 stub, so the
/// OnboardingFlowView call site compiles untouched.
///
/// `onClose` (discreet X after 3 s → back to the signed-contract screen, no
/// free zone to explore) defaults to nil: the onboarding session wires it when
/// its files free up — until then the funnel paywall simply has no X, and a
/// kill/relaunch resumes right here (`OnboardingFlags.resumeStep`).
struct PaywallGateView: View {
    let contract: ContractSnapshot?
    let date: Date
    let onContinue: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        PaywallView(context: .onboarding(contract: contract, endDate: date),
                    onFinished: onContinue,
                    onClose: onClose)
    }
}

#if DEBUG
#Preview("Paywall gate — signed contract") {
    // No EntitlementStore in the canvas → the screen shows the failure state;
    // tap "Use mock products (DEBUG)" to render the full plan UI.
    PaywallGateView(
        contract: ContractSnapshot(startingOVR: 45, projectedOVR: 78.6, preset: .monk30,
                                   durationDays: 30, reminderMinutes: 420,
                                   rules: [.init(title: "Daily workout", iconName: "figure.run"),
                                           .init(title: "Cold shower", iconName: "drop.fill")]),
        date: Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now,
        onContinue: {})
        .preferredColorScheme(.dark)
}
#endif
