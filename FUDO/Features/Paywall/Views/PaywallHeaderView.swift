import SwiftUI

/// The pitch: the PERSONAL projection from onboarding — never a feature list.
/// Reactivation keeps it factual: the data survived, the run can resume.
struct PaywallHeaderView: View {
    let context: PaywallContext

    var body: some View {
        switch context {
        case .onboarding(let contract, let endDate):
            VStack(spacing: 8) {
                Text("YOUR PROTOCOL IS READY")
                    .fudoFont(.label(12, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(FudoColor.textSecondary)

                if let contract {
                    Text("OVR \(OVREngine.displayedOVR(contract.startingOVR)) → ~\(OVREngine.displayedOVR(contract.projectedOVR))")
                        .fudoFont(.title(34, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)

                    Text("by \(OnboardingCopy.longDate(endDate))")
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.accent)

                    Text("\(contract.rules.count) rules · \(contract.durationDays) days · signed")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 2)
                } else {
                    // Contract missing (should not happen past the signature) —
                    // sell the plan, promise nothing personal we can't show.
                    Text("Unlock your protocol.")
                        .fudoFont(.title(30, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

        case .reactivation:
            VStack(spacing: 8) {
                Text("Your OVR and streak are safe.")
                    .fudoFont(.title(30, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
                Text("Pick up where you left off.")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }
}
