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
    let onBack: () -> Void

    @State private var counted: Double = 0
    @State private var revealed = false

    private static let heroHeight: CGFloat = 250
    private static let senseiHeight: CGFloat = 240
    private static let rankDelay: TimeInterval = OnboardingMetrics.countUpDuration + 0.15
    private static let copyDelay: TimeInterval = 0.6

    var body: some View {
        OnboardingScaffold(step: .diagnostic, eyebrow: "YOUR STARTING POINT",
                           title: "This is where\neveryone starts.",
                           canAdvance: true, onBack: onBack, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                Text("Almost no one moves from here.\nThe protocol is how you do.")
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 22)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.copyDelay), value: revealed)
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
                // Cream, not vermillon: the present is cream, the FUTURE is vermillon
                // (OB 13). Same grammar across the two OVR beats.
                CountUpText(value: counted) { "\(Int($0.rounded(.down)))" }
                    .fudoFont(.ovr(76))
                    .foregroundStyle(FudoColor.textPrimary)

                Text(ProgressionRankNaming.name(for: rank).uppercased())
                    .fudoFont(.label(12, weight: .semibold))
                    .kerning(2.5)
                    .foregroundStyle(FudoColor.textSecondary)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.rankDelay), value: revealed)
            }

            Spacer(minLength: 0)
        }
        .frame(height: Self.heroHeight)
    }

    private func runReveal() async {
        revealed = true
        withAnimation(.easeOut(duration: OnboardingMetrics.countUpDuration)) {
            counted = Double(ovr)
        }
        try? await Task.sleep(for: .seconds(OnboardingMetrics.countUpDuration))
        Haptics.medium()
    }
}
