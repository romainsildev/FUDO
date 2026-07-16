import SwiftUI

/// THE wordmark of the welcome act — one view, two states (device batch
/// 2026-07-16). On the splash it sits full size on the ensō; on the hooks it
/// docks at the top and STAYS across 01a/01b/01c. `OnboardingFlowView` renders
/// it ONCE above the cross-fading screens (the stable-chrome pattern of the
/// progress bar), so flipping `docked` makes the same text SLIDE up and settle
/// — never two wordmarks fading into each other.
///
/// Exact endpoints, by construction rather than by magic offsets:
/// - The layout is driven by a hidden DOCKED-size sizer text: at the top it
///   matches the slot `WelcomeHookScreen` reserves to the point, and centered
///   between symmetric spacers its own height cancels out of the math.
/// - The splash skeleton repeats SplashScreen's hidden hint block below, so the
///   centering equation is the same one that centers the ensō.
/// - The visible text renders at SPLASH size and scales down to dock: layout
///   position animates, `scaleEffect` animates, and the kerning snaps to the
///   docked value under cover of the slide (kerning itself cannot animate).
struct WelcomeWordmark: View {
    let docked: Bool

    @State private var hasAppeared = false

    private static var dockScale: CGFloat {
        OnboardingMetrics.Wordmark.dockedSize / OnboardingMetrics.Wordmark.splashSize
    }

    var body: some View {
        VStack(spacing: 0) {
            // Color.clear fillers, NOT Spacers: a stack hands Spacers only what
            // its normal views leave behind, so a greedy framed view above a bare
            // Spacer takes everything — the wordmark sank to the BOTTOM of the
            // splash (device fix 2026-07-16). Two identical greedy views split
            // the leftover equally, which is the whole centering equation here.
            Color.clear
                .frame(maxHeight: docked ? 0 : .infinity)

            // The sizer: docked metrics, so the docked resting frame IS the slot.
            Text("FUDO")
                .fudoFont(.title(OnboardingMetrics.Wordmark.dockedSize, weight: .bold))
                .kerning(OnboardingMetrics.Wordmark.dockedKerning)
                .hidden()
                .overlay {
                    Text("FUDO")
                        .fudoFont(.title(OnboardingMetrics.Wordmark.splashSize, weight: .bold))
                        .kerning(docked
                                 ? OnboardingMetrics.Wordmark.dockedKerning / Self.dockScale
                                 : OnboardingMetrics.Wordmark.splashKerning)
                        .foregroundStyle(FudoColor.textPrimary)
                        .fixedSize()
                        .scaleEffect((docked ? Self.dockScale : 1)
                                     * (hasAppeared ? 1 : OnboardingMetrics.ensoScaleFrom))
                }
                .padding(.top, docked ? OnboardingMetrics.Wordmark.dockedTopPadding : 0)

            Color.clear
                .frame(maxHeight: .infinity)

            // SplashScreen's hint block, hidden: same fonts, same padding, so the
            // wordmark centers exactly where the splash centers its ensō.
            Text("Tap anywhere")
                .fudoFont(.caption(15))
                .padding(.bottom, 40)
                .hidden()
                .frame(height: docked ? 0 : nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(AppAnimation.slow) { hasAppeared = true }
        }
    }
}
