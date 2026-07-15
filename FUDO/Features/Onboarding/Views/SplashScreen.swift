import SwiftUI

/// OB 00 — the first breath. Not an app: a dojo. No button anywhere; the whole
/// screen is the tap target, because there is nothing to decide yet.
struct SplashScreen: View {
    let onTap: () -> Void

    @State private var hasAppeared = false
    @State private var breathing = false

    private static let ensoSize: CGFloat = 200
    private static let glowIdle: Double = 0.10
    private static let glowPeak: Double = 0.22
    private static let hintIdle: Double = 0.30
    /// The brief's number: the hint sits at 45 % — present, never shouting.
    private static let hintPeak: Double = 0.45

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                mark
                Spacer()
                hint
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(AppAnimation.slow) { hasAppeared = true }
            withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
                .repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var mark: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accent.opacity(breathing ? Self.glowPeak : Self.glowIdle),
                                    .clear],
                           center: .center, startRadius: 10, endRadius: Self.ensoSize * 0.8)
                .frame(width: Self.ensoSize * 1.6, height: Self.ensoSize * 1.6)

            Image("enso-100")
                .resizable()
                .scaledToFit()
                .frame(width: Self.ensoSize)

            // SF Pro, not Bebas: the wordmark is a logo, and the frame's letterforms
            // are SF Pro Display. Bebas stays for the hooks.
            Text("FUDO")
                .fudoFont(.title(34, weight: .bold))
                .kerning(8)
                .foregroundStyle(FudoColor.textPrimary)
        }
        .scaleEffect(hasAppeared ? 1 : OnboardingMetrics.ensoScaleFrom)
        .opacity(hasAppeared ? 1 : 0)
    }

    private var hint: some View {
        Text("Tap anywhere")
            .fudoFont(.caption(15))
            .foregroundStyle(FudoColor.textPrimary)
            .opacity(hasAppeared ? (breathing ? Self.hintPeak : Self.hintIdle) : 0)
    }
}

#if DEBUG
#Preview("OB 00 — splash") {
    OnboardingPreviewChrome(clip: .dojo, isSplash: true) {
        SplashScreen(onTap: {})
    }
}
#endif
