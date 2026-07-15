import SwiftUI

/// OB 09 — the wall. The app hands him back his own words and doesn't comment on
/// them. No chevron: what he said is said. And the CTA stops being "Continue" —
/// he gives the order.
struct ReflectionScreen: View {
    let goals: Set<Goal>
    let pain: Pain?
    let struggle: OnboardingAnswers.Struggle
    let onAdvance: () -> Void

    @State private var revealed = false

    private static let enemyDelay: TimeInterval = 0.5
    private static let closeDelay: TimeInterval = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(fraction: OnboardingStep.reflection.progressFraction)
                .padding(.top, 8)
                .frame(height: 24)

            Text("GOT IT")
                .fudoFont(.label(13, weight: .bold))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
                .padding(.top, 56)

            // Derived — no \n: the sentence is built from his goals and wraps naturally.
            Text(OnboardingCopy.reflectionGoals(goals, fallback: pain))
                .fudoFont(.title(26, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 10)
                .animation(AppAnimation.standard, value: revealed)

            Text(OnboardingCopy.enemyLine(struggle))
                .fudoFont(.title(26, weight: .bold))
                .foregroundStyle(FudoColor.accent)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 32)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(Self.enemyDelay), value: revealed)

            Text(OnboardingCopy.reflectionClose)
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 26)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(Self.closeDelay), value: revealed)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) { cta }
        .onboardingWarmWash()
        .task { await runIntro() }
    }

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
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    private func runIntro() async {
        revealed = true
        try? await Task.sleep(for: .seconds(Self.enemyDelay))
        Haptics.medium()   // the enemy line IS the beat
    }
}
