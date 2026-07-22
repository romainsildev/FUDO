import SwiftUI

/// OB 20 — the reward, legibility cut (design pass 2026-07-22, BitePal/Duolingo
/// grammar: the character carries the emotion, the copy stays out of his way).
/// "WELCOME TO THE DOJO" in Bebas lives in the TOP THIRD, ABOVE the sensei —
/// never on him. The sensei is full-bleed at the bottom; a dark scrim floors
/// the lower screen so the subline never fights the art. Three elements total:
/// title → one subline → one CTA. Everything else is gone.
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

    /// The title band: top third, clear of the sensei's head.
    private static let titleTopFraction: CGFloat = 0.10
    private static let titleSize: CGFloat = 44
    /// The sensei owns the lower two thirds — capped so he never climbs under
    /// the title band.
    private static let senseiHeightFraction: CGFloat = 0.68
    private static let auraOpacity: Double = 0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                sensei(in: geometry)
                scrim
                title(in: geometry)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
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
                .frame(maxHeight: geometry.size.height * Self.senseiHeightFraction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .scaleEffect(revealed ? 1 : 0.96)
        .opacity(revealed ? 1 : 0)
    }

    /// The floor under the subline and CTA — the text never fights the art.
    private var scrim: some View {
        LinearGradient(colors: [.clear, FudoColor.bgPrimary.opacity(0.95)],
                       startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom)
            .allowsHitTesting(false)
    }

    /// Bebas, top third, above the sensei — the one display moment of the act.
    private func title(in geometry: GeometryProxy) -> some View {
        Text("WELCOME\nTO THE DOJO")
            .fudoFont(.onboardingDisplay(Self.titleSize))
            .foregroundStyle(FudoColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, geometry.size.height * Self.titleTopFraction)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .opacity(revealed ? 1 : 0)
            .animation(AppAnimation.standard.delay(0.3), value: revealed)
    }

    /// One subline, one CTA — the whole bottom of the screen. No confetti:
    /// celebrations are for milestones; arriving at the dojo is the start.
    private var footer: some View {
        VStack(spacing: 20) {
            Text("Day 1 is today. Your reminder rings tomorrow at \(OnboardingCopy.clockTime(minutes: reminderMinutes)).")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(0.5), value: revealed)

            Button(action: onAdvance) {
                Text("Let's go")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(FudoColor.accent) }
            }
            .buttonStyle(.plain)
        }
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
