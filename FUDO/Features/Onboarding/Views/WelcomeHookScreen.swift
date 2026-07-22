import SwiftUI

/// One welcome hook: the internal scale (lead → climax), the micro-line, the CTA,
/// and what the screen shows besides the video. Bebas sizes come from
/// OnboardingMetrics.Hook — the brief's numbers, never re-typed in a view.
struct WelcomeHook {
    /// What the screen carries under the hook. `.none` is a choice, not an absence:
    /// OB 01b is deliberately BARE — the phone dying on the floor is the whole point.
    /// `.senseiHero` (arbitrage 2026-07-16): the strip died — the sensei alone,
    /// centered, vermillon halo. One figure, one idea.
    enum Feature { case senseiHero, none, protocolCard }

    let clip: WelcomeClip
    let leadLines: [String]
    let leadSize: CGFloat
    let climaxLines: [String]
    let climaxSize: CGFloat
    let microLine: String?
    let ctaTitle: String
    let feature: Feature

    static let transformation = WelcomeHook(
        clip: .dojo,
        leadLines: ["IN 30 DAYS,"], leadSize: OnboardingMetrics.Hook.transformationLead,
        climaxLines: ["YOU'RE NOT", "THE SAME GUY."],
        climaxSize: OnboardingMetrics.Hook.transformationClimax,
        microLine: nil, ctaTitle: "Start", feature: .senseiHero)

    static let pain = WelcomeHook(
        clip: .phone,
        leadLines: ["YOU KNOW", "WHAT TO DO."], leadSize: OnboardingMetrics.Hook.painLead,
        climaxLines: ["YOU JUST DON'T."], climaxSize: OnboardingMetrics.Hook.painClimax,
        microLine: "Willpower isn't the fix.", ctaTitle: "Continue",
        feature: .none)

    // No micro-line (batch #3): the "60 seconds" promise got its own beat —
    // the interstitial right after this screen. The CTA hands over to it.
    static let mechanism = WelcomeHook(
        clip: .doors,
        leadLines: ["YOUR PROTOCOL.", "YOUR SCORE."], leadSize: OnboardingMetrics.Hook.mechanismLead,
        climaxLines: ["30 DAYS."], climaxSize: OnboardingMetrics.Hook.mechanismClimax,
        microLine: nil, ctaTitle: "Build mine",
        feature: .protocolCard)
}

/// OB 01a / 01b / 01c — one view, three hooks. The rule that makes them one screen
/// lives HERE and nowhere else: the lead is always cream, the CLIMAX is always
/// vermillon, and the last line is the one he keeps.
struct WelcomeHookScreen: View {
    let hook: WelcomeHook
    let onAdvance: () -> Void

    @State private var revealed = false
    @State private var cardChecks = 0
    @State private var haloBreathing = false

    /// Each hook line lands after the one above it — the climax arrives last.
    private static let lineStagger: TimeInterval = 0.12
    private static let featureDelay: TimeInterval = 0.45
    private static let checkStagger: TimeInterval = 0.10

    var body: some View {
        VStack(spacing: 0) {
            // The wordmark is drawn ONCE by OnboardingFlowView (WelcomeWordmark):
            // it slides up from the splash and stays docked across all three
            // hooks. The screen only RESERVES its slot so nothing collides.
            wordmarkSlot
                .padding(.top, OnboardingMetrics.Wordmark.dockedTopPadding)
            Spacer(minLength: 0)
            feature
            hookStack
                .padding(.top, hook.feature == .senseiHero ? 28 : 0)
            if hook.feature == .protocolCard {
                // Inset + extra air: the tilt and the glass lensing both reach
                // past the layout box — 24pt of gap let the corner clip the
                // micro-line on device (pass 2, 2026-07-16).
                ProtocolGlassCard(checksRevealed: cardChecks)
                    .padding(.horizontal, 10)
                    .padding(.top, 36)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.97)
                    .offset(y: revealed ? 0 : 14)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { cta }
        .task { await runIntro() }
    }

    // MARK: - Pieces

    /// Same metrics as WelcomeWordmark's docked state, hidden: the slot IS the
    /// wordmark's resting frame, guaranteed by sharing the constants.
    private var wordmarkSlot: some View {
        Text("FUDO")
            .fudoFont(.title(OnboardingMetrics.Wordmark.dockedSize, weight: .bold))
            .kerning(OnboardingMetrics.Wordmark.dockedKerning)
            .hidden()
    }

    @ViewBuilder private var feature: some View {
        switch hook.feature {
        case .senseiHero:
            SenseiHero(haloBreathing: haloBreathing)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 12)
        case .none, .protocolCard:
            EmptyView()
        }
    }

    private var hookStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(hook.leadLines.enumerated()), id: \.offset) { index, line in
                hookLine(line, size: hook.leadSize, color: FudoColor.textPrimary, index: index)
            }
            ForEach(Array(hook.climaxLines.enumerated()), id: \.offset) { index, line in
                hookLine(line, size: hook.climaxSize, color: FudoColor.accent,
                         index: hook.leadLines.count + index)
            }
            if let microLine = hook.microLine {
                Text(microLine)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .opacity(revealed ? 1 : 0)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// One Bebas line. `minimumScaleFactor` is not decoration: at accessibility
    /// sizes a 62 pt line would run off the phone, and the hook must never wrap.
    private func hookLine(_ text: String, size: CGFloat, color: Color, index: Int) -> some View {
        Text(text)
            .fudoFont(.onboardingDisplay(size))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(OnboardingMetrics.Hook.minimumScale)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(AppAnimation.standard.delay(Double(index) * Self.lineStagger), value: revealed)
    }

    private var cta: some View {
        Button(action: onAdvance) {
            Text(hook.ctaTitle)
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

    // MARK: - Choreography

    private func runIntro() async {
        withAnimation(AppAnimation.slow) { revealed = true }
        withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
            .repeatForever(autoreverses: true)) {
            haloBreathing = true
        }
        guard hook.feature == .protocolCard else { return }
        // The card fills itself in, like a day that works. Nothing flashy.
        try? await Task.sleep(for: .seconds(Self.featureDelay + 0.25))
        for _ in ProtocolGlassCardChecks.all {
            withAnimation(AppAnimation.standard) { cardChecks += 1 }
            try? await Task.sleep(for: .seconds(Self.checkStagger))
        }
    }
}

/// The card has three rows; the stagger walks them without the screen knowing
/// the card's internals.
private enum ProtocolGlassCardChecks {
    static let all = 0..<3
}

#if DEBUG
#Preview("OB 01a — the transformation") {
    OnboardingPreviewChrome(clip: .dojo, showsWordmark: true) {
        WelcomeHookScreen(hook: .transformation, onAdvance: {})
    }
}

#Preview("OB 01b — the pain") {
    OnboardingPreviewChrome(clip: .phone, showsWordmark: true) {
        WelcomeHookScreen(hook: .pain, onAdvance: {})
    }
}

#Preview("OB 01c — the mechanism") {
    OnboardingPreviewChrome(clip: .doors, showsWordmark: true) {
        WelcomeHookScreen(hook: .mechanism, onAdvance: {})
    }
}
#endif

/// OB 01a's figure, final form (arbitrage 2026-07-16 — the peasant strip died
/// after two device passes): the sensei ALONE, centered, breathing vermillon
/// halo, grounded by his shadow. One figure, one idea; the hook says the rest.
private struct SenseiHero: View {
    let haloBreathing: Bool

    private static let senseiHeight: CGFloat = 190

    var body: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accent.opacity(haloBreathing ? 0.34 : 0.22), .clear],
                           center: .center, startRadius: 10, endRadius: Self.senseiHeight * 0.7)
                .frame(width: Self.senseiHeight * 1.4, height: Self.senseiHeight * 1.4)

            VStack(spacing: 0) {
                SenseiAssetProvider.image(for: .sensei)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.senseiHeight)
                Ellipse()
                    .fill(.black.opacity(0.5))
                    .frame(width: 95, height: 12)
                    .blur(radius: 8)
                    .offset(y: -6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}
