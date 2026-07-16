import SwiftUI

/// The funnel's only progress feedback. The fraction comes from OnboardingStep —
/// counted from the enum, never hand-numbered.
///
/// STABLE by doctrine (UX pass 2026-07-16): the bar only ever FILLS. It lives in
/// `OnboardingChromeHeader`, OUTSIDE the sliding screens, so no transition can
/// drag it sideways.
///
/// A nil fraction renders nothing at all (not an empty track).
struct OnboardingProgressBar: View {
    let fraction: Double?

    private static let height: CGFloat = 3

    var body: some View {
        if let fraction {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FudoColor.border)
                    Capsule()
                        .fill(FudoColor.accent)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: Self.height)
            .animation(AppAnimation.standard, value: fraction)
        }
    }
}

/// Back + bar, rendered ONCE by the flow container above the sliding screens.
/// The chevron keeps a reserved slot on every bar-carrying step and only fades:
/// the bar's origin never moves, so the fill is the only motion it ever shows.
struct OnboardingChromeHeader: View {
    let step: OnboardingStep
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    Haptics.light()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.trailing, 4)
                }
                .buttonStyle(.plain)
                .opacity(step.showsBack ? 1 : 0)
                .disabled(!step.showsBack)
                .animation(AppAnimation.standard, value: step.showsBack)

                OnboardingProgressBar(fraction: step.progressFraction)
            }
            .frame(height: 24)
            .padding(.top, 8)
            .padding(.horizontal, FudoSpacing.screenMargin)

            Spacer(minLength: 0)
        }
    }
}
