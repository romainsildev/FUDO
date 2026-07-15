import SwiftUI

/// The paywall's SLOT in the funnel — Session 6 fills it in (RevenueCat,
/// trial-first, mandatory loading + retry, restore, real localized prices).
///
/// Not `#if DEBUG`: the step exists in the machine in Release too, and removing
/// it would break the routing. It ships as this until S6 replaces the body — and
/// it must not ship to the App Store in this state (a stub CTA where a purchase
/// belongs is exactly the dead button Guideline 2.1 rejects).
///
/// It reads the ContractSnapshot on purpose: rendering the signed numbers proves,
/// on device, that the kill-safety checkpoint survived — which is the whole reason
/// this stub exists now instead of in S6.
struct PaywallGateView: View {
    let contract: ContractSnapshot?
    let date: Date
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Your protocol is ready.")
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .multilineTextAlignment(.center)

            if let contract {
                Text("OVR \(OVREngine.displayedOVR(contract.startingOVR)) → ~\(OVREngine.displayedOVR(contract.projectedOVR)) by \(OnboardingCopy.longDate(date))")
                    .fudoFont(.headline(17))
                    .foregroundStyle(FudoColor.accent)
                    .padding(.top, 10)

                Text("\(contract.rules.count) rules · \(contract.durationDays) days · signed")
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 6)
            }

            Text("Paywall — Session 6")
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, FudoSpacing.sectionGap)

            Spacer()
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { cta }
    }

    private var cta: some View {
        Button(action: onContinue) {
            Text("Continue (stub)")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }
}

#if DEBUG
#Preview("Paywall gate — signed contract") {
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
