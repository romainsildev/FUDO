import SwiftUI

/// OB 21 — the last retention lever (#1 of the list), placed where it costs
/// nothing: he's already committed, already served. Three steps, an honest way
/// out, and we let him go to his dojo.
struct WidgetPromoScreen: View {
    let onFinish: () -> Void

    @State private var revealed = false
    @State private var ringProgress: Double = 0

    private static let mockSize: CGFloat = 160
    private static let ringDiameter: CGFloat = 62
    private static let ringWidth: CGFloat = 5
    private static let stepStagger: TimeInterval = 0.06
    private static let ringDrawDuration: TimeInterval = 0.6

    /// Demo values: this is a POSTER of the widget, not his state (he's on day 1).
    /// Same call as the OB 01c card — the product's advert, not the player's data.
    private static let mockOVR = 47
    private static let mockDay = 12
    private static let mockDuration = 30
    private static let mockStreak = 11

    private static let steps = ["Long-press your home screen",
                                "Tap + and search \"FUDO\"",
                                "Add the widget"]

    var body: some View {
        OnboardingScaffold(step: .widgetPromo, 
                           title: "Put your streak\non your home screen.",
                           subtitle: SocialProofCopy.widgetStake,
                           ctaTitle: "I've added it",
                           canAdvance: true, onAdvance: onFinish) {
            VStack(spacing: 0) {
                widgetMock
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                stepsList
                    .padding(.top, FudoSpacing.sectionGap)
            }
        }
        // "Later" sits directly under the primary CTA (batch #10): a second
        // bottom inset stacks below the scaffold's own, not adrift mid-screen.
        .safeAreaInset(edge: .bottom) {
            laterButton
                .padding(.bottom, 8)
        }
        .task { await runIntro() }
    }

    private var widgetMock: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(FudoColor.border, lineWidth: Self.ringWidth)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Self.mockOVR)")
                    .fudoFont(.metric(24))
                    .foregroundStyle(FudoColor.textPrimary)
            }
            .frame(width: Self.ringDiameter, height: Self.ringDiameter)

            Text("DAY \(Self.mockDay) / \(Self.mockDuration)")
                .fudoFont(.label(12, weight: .bold))
                .kerning(1)
                .foregroundStyle(FudoColor.textPrimary)

            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .fudoFont(.glyph(12))
                    .foregroundStyle(FudoGradient.flame)
                Text("\(Self.mockStreak)")
                    .fudoFont(.stat(13))
                    .foregroundStyle(FudoColor.celebrationGold)
            }
        }
        .frame(width: Self.mockSize, height: Self.mockSize)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .scaleEffect(revealed ? 1 : 0.94)
        .opacity(revealed ? 1 : 0)
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fudoFont(.body(15, weight: .medium))
                        .foregroundStyle(FudoColor.textSecondary)
                    Text(step)
                        .fudoFont(.body(15, weight: .medium))
                        .foregroundStyle(FudoColor.textPrimary)
                }
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(0.4 + Double(index) * Self.stepStagger),
                           value: revealed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Both buttons do the same thing. No API tells us whether a widget was
    /// actually added, so pretending to know would be worse than owning it:
    /// "I've added it" is the proud path, "Later" the honest one.
    private var laterButton: some View {
        Button(action: onFinish) {
            Text("Later")
                .fudoFont(.headline(15))
                .foregroundStyle(FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func runIntro() async {
        withAnimation(AppAnimation.slow) { revealed = true }
        // The widget fills itself in under his eyes — the thing he's being sold.
        withAnimation(.easeOut(duration: Self.ringDrawDuration)) {
            ringProgress = Double(Self.mockOVR) / GameConfig.ovrMax
        }
    }
}

#if DEBUG
#Preview("OB 21 — widget promo") {
    OnboardingPreviewChrome {
        WidgetPromoScreen(onFinish: {})
    }
}
#endif
