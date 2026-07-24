import SwiftUI

/// OB 09 — the wall, SEQUENCED (Romain 2026-07-16, option A): three beats, one
/// idea each. (1) his goals, calm, off-white · (2) the enemy STAMPS in — giant
/// Bebas vermillon, a seal hitting paper, heavy haptic · (3) one closing line,
/// then the CTA. No chevron: what he said is said. And the CTA stops being
/// "Continue" — he gives the order.
struct ReflectionScreen: View {
    let goals: Set<Goal>
    let pain: Pain?
    let struggle: OnboardingAnswers.Struggle
    let onAdvance: () -> Void

    @State private var goalsShown = false
    @State private var enemyStamped = false
    @State private var closeShown = false

    /// 0.4–0.6 s between beats — never more (the wall must not drag).
    private static let beatGap: TimeInterval = 0.55
    /// The stamp: lands from above at scale, one bounce, done. The spring is a
    /// deliberate exception to the 0.4-0.6 ease rule — a seal doesn't ease in.
    // Intentional stamp punch — a soft spring, device-validated exception to the
    // 0.4–0.6 s ease rule (F19, audit 2026-07-23: feel kept, comment added).
    private static let stampAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.65)
    private static let stampFromScale: CGFloat = 1.45

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — the bar renders at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            // The block CENTERS between the chrome and the CTA (layout fix
            // 2026-07-16): symmetric spacers — the wall breathes above AND below.
            Spacer(minLength: 0)

            // Beat 1 — his goals, calm. Derived, no \n: the sentence is built
            // from his answers and wraps naturally.
            Text(OnboardingCopy.reflectionGoals(goals, fallback: pain))
                .fudoFont(.title(26, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(goalsShown ? 1 : 0)
                .offset(y: goalsShown ? 0 : 10)

            // Beat 2 — the stamp. Hook-sized Bebas (internal scale fills the
            // width), vermillon, lands as one block.
            VStack(alignment: .leading, spacing: 2) {
                Text(OnboardingCopy.enemyLabel)
                    .fudoFont(.onboardingDisplay(38))
                    .foregroundStyle(FudoColor.textPrimary)
                Text(OnboardingCopy.enemyStamp(struggle))
                    .fudoFont(.onboardingDisplay(56))
                    .foregroundStyle(FudoColor.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.top, 40)
            .opacity(enemyStamped ? 1 : 0)
            .scaleEffect(enemyStamped ? 1 : Self.stampFromScale, anchor: .leading)

            // Beat 3 — the pivot out of the wound.
            Text(OnboardingCopy.reflectionClose)
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 32)
                .opacity(closeShown ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) { cta }
        .onboardingWarmWash()
        .task { await runIntro() }
    }

    /// The CTA belongs to beat 3 — invisible before it, and DISABLED while
    /// invisible (a live button he can't see is the pitfall, not a delayed one).
    private var cta: some View {
        Button(action: onAdvance) {
            Text("Build my protocol")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
        .disabled(!closeShown)
        .opacity(closeShown ? 1 : 0)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    private func runIntro() async {
        withAnimation(AppAnimation.standard) { goalsShown = true }
        try? await Task.sleep(for: .seconds(Self.beatGap))
        withAnimation(Self.stampAnimation) { enemyStamped = true }
        Haptics.heavy()   // the seal lands WITH the stamp
        try? await Task.sleep(for: .seconds(Self.beatGap))
        withAnimation(AppAnimation.standard) { closeShown = true }
    }
}

#if DEBUG
#Preview("OB 09 — reflection (three goals)") {
    OnboardingPreviewChrome {
        ReflectionScreen(goals: [.leanerBody, .killScrolling, .harderMindset],
                         pain: .trainingConsistently, struggle: .threeDaysMax,
                         onAdvance: {})
    }
}

/// One goal, one clause — the sentence must still read like a sentence.
#Preview("OB 09 — reflection (one goal)") {
    OnboardingPreviewChrome {
        ReflectionScreen(goals: [.coldShowers], pain: .wakingUpEarly,
                         struggle: .startStrongThenQuit, onAdvance: {})
    }
}

/// Goals can't be empty in the funnel (the CTA gates it), but the fallback is the
/// copy engine's contract — worth seeing it hold.
#Preview("OB 09 — reflection (pain fallback)") {
    OnboardingPreviewChrome {
        ReflectionScreen(goals: [], pain: .doomscrolling,
                         struggle: .cantEvenStart, onAdvance: {})
    }
}
#endif
