import SwiftUI

/// One welcome hook: the internal scale (lead → climax), the micro-line, the CTA,
/// and what the screen shows besides the video. Bebas sizes come from
/// OnboardingMetrics.Hook — the brief's numbers, never re-typed in a view.
struct WelcomeHook {
    /// What the screen carries under the hook. `.none` is a choice, not an absence:
    /// OB 01b is deliberately BARE — the phone dying on the floor is the whole point.
    enum Feature { case transformationStrip, none, protocolCard }

    let clip: WelcomeClip
    let leadLines: [String]
    let leadSize: CGFloat
    let climaxLines: [String]
    let climaxSize: CGFloat
    let microLine: String?
    let ctaTitle: String
    let showsWordmark: Bool
    let feature: Feature

    static let transformation = WelcomeHook(
        clip: .dojo,
        leadLines: ["IN 30 DAYS,"], leadSize: OnboardingMetrics.Hook.transformationLead,
        climaxLines: ["YOU'RE NOT", "THE SAME GUY."],
        climaxSize: OnboardingMetrics.Hook.transformationClimax,
        microLine: nil, ctaTitle: "Start", showsWordmark: true, feature: .transformationStrip)

    static let pain = WelcomeHook(
        clip: .phone,
        leadLines: ["YOU KNOW", "WHAT TO DO."], leadSize: OnboardingMetrics.Hook.painLead,
        climaxLines: ["YOU JUST DON'T."], climaxSize: OnboardingMetrics.Hook.painClimax,
        microLine: "Willpower isn't the fix.", ctaTitle: "Continue",
        showsWordmark: false, feature: .none)

    static let mechanism = WelcomeHook(
        clip: .doors,
        leadLines: ["YOUR PROTOCOL.", "YOUR SCORE."], leadSize: OnboardingMetrics.Hook.mechanismLead,
        climaxLines: ["30 DAYS."], climaxSize: OnboardingMetrics.Hook.mechanismClimax,
        microLine: "60 seconds to build yours.", ctaTitle: "Continue",
        showsWordmark: false, feature: .protocolCard)
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
            if hook.showsWordmark {
                wordmark
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
            feature
            hookStack
                .padding(.top, hook.feature == .transformationStrip ? 28 : 0)
            if hook.feature == .protocolCard {
                ProtocolGlassCard(checksRevealed: cardChecks)
                    .padding(.top, 24)
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

    private var wordmark: some View {
        Text("FUDO")
            .fudoFont(.title(20, weight: .bold))
            .kerning(6)
            .foregroundStyle(FudoColor.textPrimary)
    }

    @ViewBuilder private var feature: some View {
        switch hook.feature {
        case .transformationStrip:
            TransformationStrip(haloBreathing: haloBreathing)
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

/// OB 01a's strip: the past on the left (small, blurred, faded), the future on the
/// right (large, haloed, grounded). Vermillon dots grow between them — progression,
/// not an arrow. The focal point is the man he becomes.
private struct TransformationStrip: View {
    let haloBreathing: Bool

    private static let stripHeight: CGFloat = 200
    private static let pastHeight: CGFloat = 130
    private static let futureHeight: CGFloat = 175
    private static let dotSizes: [CGFloat] = [3, 5, 7]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                past
                Spacer(minLength: 12)
                dots
                Spacer(minLength: 12)
                future
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: Self.stripHeight)
        .clipped()
    }

    private var past: some View {
        SenseiAssetProvider.image(for: .novice)
            .resizable()
            .scaledToFit()
            .frame(height: Self.pastHeight)
            .blur(radius: 2.5)
            .saturation(0.5)
            .opacity(0.45)
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(Array(Self.dotSizes.enumerated()), id: \.offset) { _, size in
                Circle()
                    .fill(FudoColor.accent)
                    .frame(width: size, height: size)
            }
        }
    }

    private var future: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accent.opacity(haloBreathing ? 0.34 : 0.22), .clear],
                           center: .center, startRadius: 10, endRadius: Self.futureHeight * 0.7)
                .frame(width: Self.futureHeight * 1.4, height: Self.futureHeight * 1.4)

            VStack(spacing: 0) {
                SenseiAssetProvider.image(for: .sensei)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.futureHeight)
                Ellipse()
                    .fill(.black.opacity(0.5))
                    .frame(width: 90, height: 12)
                    .blur(radius: 8)
                    .offset(y: -6)
            }
        }
    }
}
