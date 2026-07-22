import SwiftUI

/// OB 10 — the first of the two OVR beats (the other is the projection, OB 13).
/// He gets a number that DESCRIBES him. Not a score he earned: a starting point,
/// plus the fact that almost nobody moves from it. Threat and invitation in the
/// same breath.
///
/// D1 (Romain, 2026-07-15): this number is the FLOOR — the commitment answer
/// (OB 16) can only raise it. He never watches it drop.
struct DiagnosticScreen: View {
    let ovr: Int
    let rank: Rank
    let onAdvance: () -> Void

    @State private var counted: Double = 0
    @State private var revealed = false
    @State private var rankStamped = false

    private static let heroHeight: CGFloat = 250
    private static let senseiHeight: CGFloat = 240
    /// Faster than OB 06's 1.2 s: this number is smaller and the screen has
    /// two beats after it (stamp, closing line).
    private static let countUp: TimeInterval = 0.8
    /// The rank stamps in like OB 09's seal — same spring, same exception to
    /// the ease rule.
    private static let stampAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.65)
    private static let stampFromScale: CGFloat = 1.45

    /// "YOUR STARTING POINT" IS the screen's hierarchy (UX pass 2026-07-16):
    /// Bebas display on top, everything else below it, stripped. The scaffold's
    /// title stays nil — this headline replaces it. The block CENTERS between
    /// the chrome and the CTA (layout fix 2026-07-16), like OB 06/09.
    var body: some View {
        OnboardingScaffold(step: .diagnostic, canAdvance: true,
                           centersVertically: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR\nSTARTING POINT")
                    .fudoFont(.onboardingDisplay(44))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                hero
                    .padding(.top, 24)

                Text("Almost no one moves from here.\nThe protocol is how you do.")
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 22)
                    .opacity(rankStamped ? 0.45 : 0)
                    .animation(AppAnimation.standard.delay(0.25), value: rankStamped)
            }
        }
        .task { await runReveal() }
    }

    /// The peasant and the number, side by side: this is him, and this is his score.
    private var hero: some View {
        HStack(spacing: 8) {
            SenseiAssetProvider.image(for: rank)
                .resizable()
                .scaledToFit()
                .frame(height: Self.senseiHeight)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(revealed ? 1 : 0.97)
                .animation(AppAnimation.slow, value: revealed)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                // Muted, drained red — the BAD score. OB 13's full-vermillon ~78
                // is the deliverance by contrast (Romain 2026-07-16).
                CountUpText(value: counted) { "\(Int($0.rounded(.down)))" }
                    .fudoFont(.ovr(76))
                    .foregroundStyle(FudoColor.accentMuted)

                // Stamps in AFTER the number lands — never alongside it.
                Text(rank.displayName.uppercased())
                    .fudoFont(.label(12, weight: .semibold))
                    .kerning(2.5)
                    .foregroundStyle(FudoColor.textSecondary)
                    .opacity(rankStamped ? 1 : 0)
                    .scaleEffect(rankStamped ? 1 : Self.stampFromScale, anchor: .leading)
            }

            Spacer(minLength: 0)
        }
        .frame(height: Self.heroHeight)
    }

    private func runReveal() async {
        revealed = true
        withAnimation(.easeOut(duration: Self.countUp)) {
            counted = Double(ovr)
        }
        try? await Task.sleep(for: .seconds(Self.countUp))
        Haptics.medium()   // the landing
        withAnimation(Self.stampAnimation) { rankStamped = true }
    }
}

#if DEBUG
/// The PRD's canonical number.
#Preview("OB 10 — OVR 43 (Novice)") {
    OnboardingPreviewChrome {
        DiagnosticScreen(ovr: 43, rank: .novice, onAdvance: {})
    }
}

/// The engine's floor: every answer at its worst. Still Novice — as it must be.
#Preview("OB 10 — OVR 40 (floor)") {
    OnboardingPreviewChrome {
        DiagnosticScreen(ovr: 40, rank: .novice, onAdvance: {})
    }
}

/// The engine's ceiling for a starting player: 50 = Disciple, the only rank
/// besides Novice this screen can ever show.
#Preview("OB 10 — OVR 50 (ceiling, Disciple)") {
    OnboardingPreviewChrome {
        DiagnosticScreen(ovr: 50, rank: .disciple, onAdvance: {})
    }
}
#endif
