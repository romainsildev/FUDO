import SwiftUI

/// OB 20 — the reward. No more questions, no more numbers: the sensei is there,
/// full height, and he gives one thing to do tonight. The funnel ends on a simple,
/// holdable order — not a list.
///
/// The sensei shown is HIS rank, the Novice peasant — not the frame's white-gi
/// master. He hasn't earned that one, and the very next screen (Home) would
/// contradict it. Flagged to Romain: one line to flip if the frame was deliberate.
///
/// D2: "Day 1 is today" — the frame's "starts tomorrow" contradicted the engine
/// (`startChallenge` forces `startDate = effectiveDay`). What moved is the copy.
struct WelcomeDojoScreen: View {
    let rank: Rank
    let reminderMinutes: Int
    let onAdvance: () -> Void

    @State private var revealed = false
    @State private var auraBreathing = false

    private static let titleTopFraction: CGFloat = 0.48
    private static let auraOpacity: Double = 0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                sensei(in: geometry)
                scrim
                copy(in: geometry)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { cta }
        .onAppear {
            withAnimation(AppAnimation.slow) { revealed = true }
            withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
                .repeatForever(autoreverses: true)) {
                auraBreathing = true
            }
        }
    }

    private func sensei(in geometry: GeometryProxy) -> some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accent.opacity(auraBreathing ? Self.auraOpacity : 0.18),
                                    .clear],
                           center: .center, startRadius: 20, endRadius: geometry.size.width * 0.7)

            SenseiAssetProvider.image(for: rank)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: geometry.size.height * 0.9)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .scaleEffect(revealed ? 1 : 0.96)
        .opacity(revealed ? 1 : 0)
    }

    /// The copy sits over his chest — it needs its own floor to stay legible.
    private var scrim: some View {
        LinearGradient(colors: [.clear, FudoColor.bgPrimary.opacity(0.95)],
                       startPoint: .center, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    private func copy(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: geometry.size.height * Self.titleTopFraction)

            Text("Welcome to the dojo.")
                .fudoFont(.title(30, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(0.3), value: revealed)

            Text("Day 1 is today. Your reminder rings tomorrow at \(OnboardingCopy.clockTime(minutes: reminderMinutes)).\nTonight: sleep. That's the first order.")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(0.5), value: revealed)

            Spacer()
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
    }

    /// No confetti: celebrations are for milestones (100 % day, rank-up, challenge
    /// complete). Arriving at the dojo isn't one — it's the start.
    private var cta: some View {
        Button(action: onAdvance) {
            Text("Let's go")
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
/// What a real user sees: he starts at Novice, so the peasant is who greets him.
#Preview("OB 20 — welcome dojo (Novice)") {
    WelcomeDojoScreen(rank: .novice, reminderMinutes: 420, onAdvance: {})
        .preferredColorScheme(.dark)
}

/// The frame's white-gi figure, for comparison — this is the rank he'd have to
/// earn. Romain's call (see the type's note).
#Preview("OB 20 — welcome dojo (frame's sensei)") {
    WelcomeDojoScreen(rank: .disciple, reminderMinutes: 390, onAdvance: {})
        .preferredColorScheme(.dark)
}
#endif
