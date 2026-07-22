import SwiftUI

/// The launch beat (batch #3, re-cut batch #4) — between the last hook and the
/// first question. Three-step choreography: "ONLY 60 SECONDS" scales in while
/// the chrono ring arms, then "AND WE LOCK YOU IN" lands under it (haptic),
/// then the CTA slides up. No auto-advance anymore: the lock line earns the
/// tap. The bar stays hidden (welcome rule); the beat is not a quiz step.
///
/// Plays ONCE per funnel run: `hasPlayed` (view-model session memory) makes a
/// re-entry — back from the quiz — land on the FINISHED state, never a replay.
struct SixtySecondsScreen: View {
    let hasPlayed: Bool
    let onPlayed: () -> Void
    let onAdvance: () -> Void

    @State private var revealed = false
    @State private var ringProgress: CGFloat = 0
    @State private var lockLineShown = false
    @State private var ctaShown = false

    var body: some View {
        VStack(spacing: 18) {
            Text("ONLY")
                .fudoFont(.onboardingDisplay(34))
                .foregroundStyle(FudoColor.textPrimary)

            ZStack {
                Circle()
                    .stroke(FudoColor.border, lineWidth: OnboardingMetrics.SixtySeconds.ringWidth)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: OnboardingMetrics.SixtySeconds.ringWidth,
                                               lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("60")
                    .fudoFont(.onboardingDisplay(96))
                    .foregroundStyle(FudoColor.accent)
            }
            .frame(width: OnboardingMetrics.SixtySeconds.ringDiameter,
                   height: OnboardingMetrics.SixtySeconds.ringDiameter)

            Text("SECONDS")
                .fudoFont(.onboardingDisplay(34))
                .foregroundStyle(FudoColor.textPrimary)

            // The lock line — lead cream, climax vermillon, same hook grammar
            // as the welcome act. It OWNS the CTA that follows.
            (Text("AND WE ").foregroundStyle(FudoColor.textPrimary)
             + Text("LOCK YOU IN").foregroundStyle(FudoColor.accent))
                .fudoFont(.onboardingDisplay(30))
                .lineLimit(1)
                .minimumScaleFactor(OnboardingMetrics.Hook.minimumScale)
                .opacity(lockLineShown ? 1 : 0)
                .offset(y: lockLineShown ? 0 : 10)
                .padding(.top, 10)
        }
        .scaleEffect(revealed ? 1 : OnboardingMetrics.SixtySeconds.scaleFrom)
        .opacity(revealed ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { cta }
        .task { await run() }
    }

    private var cta: some View {
        Button(action: onAdvance) {
            Text("Lock me in")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
        .opacity(ctaShown ? 1 : 0)
        .offset(y: ctaShown ? 0 : 24)
        .allowsHitTesting(ctaShown)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    /// Intro → lock line (haptic) → CTA. A re-entry poses the finished state
    /// cold; a cancelled sleep (view torn down mid-beat) stops the sequence.
    private func run() async {
        guard !hasPlayed else {
            revealed = true
            ringProgress = 1
            lockLineShown = true
            ctaShown = true
            return
        }

        Haptics.medium()
        withAnimation(AppAnimation.spring) { revealed = true }
        withAnimation(.easeInOut(duration: OnboardingMetrics.SixtySeconds.ringFill)) {
            ringProgress = 1
        }

        try? await Task.sleep(for: .seconds(OnboardingMetrics.SixtySeconds.intro))
        guard !Task.isCancelled else { return }
        Haptics.medium()
        withAnimation(AppAnimation.standard) { lockLineShown = true }

        try? await Task.sleep(for: .seconds(OnboardingMetrics.SixtySeconds.ctaDelay))
        guard !Task.isCancelled else { return }
        withAnimation(AppAnimation.standard) { ctaShown = true }
        onPlayed()
    }
}

#if DEBUG
#Preview("Launch beat — full choreography") {
    OnboardingPreviewChrome {
        SixtySecondsScreen(hasPlayed: false, onPlayed: {}, onAdvance: {})
    }
}

/// Back from the quiz: the finished state, posed cold — no replay.
#Preview("Launch beat — already played") {
    OnboardingPreviewChrome {
        SixtySecondsScreen(hasPlayed: true, onPlayed: {}, onAdvance: {})
    }
}
#endif
