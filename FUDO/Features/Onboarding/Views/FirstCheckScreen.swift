import SwiftUI

/// OB 14 — the only screen where his HAND learns something: the 1 s hold, the
/// ring filling, the haptic climbing, the seal. And his first check isn't a
/// task — it's "I started". The flame lights before day 1 even exists.
///
/// ⚠️ This is a DEMO. The challenge does not exist yet (it's born at OB 19), so
/// nothing here calls `store.checkTask`, no OVR moves, no streak is written. The
/// "Day 0" flame is pure visual. Wiring a real check here would hand him a free
/// delta and break the anti-farming pool — do not "finish" this screen.
struct FirstCheckScreen: View {
    let onAdvance: () -> Void

    @State private var hasSealed = false
    @State private var revealed = false
    @State private var inviting = false
    @State private var showsFlame = false
    @State private var burstTrigger = 0

    private static let flameDelay: TimeInterval = 0.45
    private static let cardDelay: TimeInterval = 0.15
    private static let ringDelay: TimeInterval = 0.3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — the bar renders at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            Text("FIRST ACTION")
                .fudoFont(.label(13, weight: .bold))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
                .padding(.top, 56)

            Text("Validate your first action.")
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 10)

            quoteCard
                .padding(.top, 28)

            holdRing
                .frame(maxWidth: .infinity)
                .padding(.top, 56)

            Text("Hold to check.")
                .fudoFont(.caption(13))
                .foregroundStyle(FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            flame
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingWarmWash(.bottom)
        .onAppear { runIntro() }
    }

    /// The frame underlines this card in vermillon: the sentence is the point.
    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\"I started my Monk Mode.\"")
                .fudoFont(.headline(17))
                .foregroundStyle(FudoColor.textPrimary)
            Text("Your first check. It counts.")
                .fudoFont(.caption(13))
                .foregroundStyle(FudoColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.accent.opacity(0.55), lineWidth: 1)
        }
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Self.cardDelay), value: revealed)
    }

    private var holdRing: some View {
        ZStack {
            // strokeBorder insets like HoldToConfirm does, so the track and the
            // progress ring sit on exactly the same circle.
            Circle()
                .strokeBorder(FudoColor.border, lineWidth: OnboardingMetrics.firstCheckRingWidth)

            if hasSealed {
                Image(systemName: "checkmark")
                    .fudoFont(.glyph(34, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .transition(.opacity)
            } else {
                Text("HOLD")
                    .fudoFont(.label(15, weight: .bold))
                    .kerning(4)
                    .foregroundStyle(FudoColor.textPrimary)
                    .transition(.opacity)
            }

            if burstTrigger > 0 {
                // From the RING, like the Home's day ring — not a centre pop.
                ParticleBurstView(color: FudoColor.accent,
                                  particleCount: ParticleBurstMetrics.checkCount,
                                  originRadius: OnboardingMetrics.firstCheckRingDiameter / 2)
                    .id(burstTrigger)
            }
        }
        .frame(width: OnboardingMetrics.firstCheckRingDiameter,
               height: OnboardingMetrics.firstCheckRingDiameter)
        .contentShape(Circle())
        // The invitation breathes until he holds — he should understand without reading.
        .opacity(hasSealed ? 1 : (inviting ? 1 : 0.75))
        .holdToConfirm(in: Circle(), completionHaptic: .success,
                       ringColor: FudoColor.accent,
                       ringWidth: OnboardingMetrics.firstCheckRingWidth) { seal() }
        .scaleEffect(revealed ? 1 : 0.96)
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Self.ringDelay), value: revealed)
    }

    private var flame: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(FudoGradient.flame)
            Text("Day 0 — streak ignited")
                .foregroundStyle(FudoColor.celebrationGold)
        }
        .fudoFont(.stat(15))
        .opacity(showsFlame ? 1 : 0)
        .offset(y: showsFlame ? 0 : 10)
    }

    private func runIntro() {
        withAnimation(AppAnimation.standard) { revealed = true }
        withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
            .repeatForever(autoreverses: true)) {
            inviting = true
        }
    }

    /// HoldToConfirm already fires onConfirm once per hold, but it re-arms after
    /// its seal delay — a second hold during the settle would advance twice.
    private func seal() {
        guard !hasSealed else { return }
        hasSealed = true
        burstTrigger += 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.flameDelay))
            Haptics.medium()
            withAnimation(AppAnimation.standard) { showsFlame = true }
            try? await Task.sleep(for: .seconds(OnboardingMetrics.firstCheckSettle))
            onAdvance()   // the gesture IS the CTA — the frame has no button
        }
    }
}

#if DEBUG
/// The hold and the seal only exist under a finger — the canvas shows the resting
/// state. The gesture itself is a device check.
#Preview("OB 14 — first hold") {
    OnboardingPreviewChrome {
        FirstCheckScreen(onAdvance: {})
    }
}
#endif
