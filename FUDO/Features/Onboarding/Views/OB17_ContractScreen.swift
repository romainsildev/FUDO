import SwiftUI

/// OB 17 (design pass 2026-07-22 — Romain: the SIGNED stamp supersedes the
/// sober payoff; the one INTACT rule: nothing ever covers the signature).
///
/// STATE 1 — before the seal: the recap compacted into one card (GOING keeps
/// the vermilion), then the DOMINANT element: the signature card — tracked
/// commit label, a real baseline, "Sign with your finger". NO price anywhere
/// on screen: the price lives at the PAYWALL only.
///
/// THE HOLD — the white spinning ring is GONE. The capsule FILLS with
/// vermilion left to right (determinate, mirrors the hold clock) while a glow
/// intensifies around it, and the haptic is one continuous 2.5 s ramp
/// (CHHapticEngine, intensity 0.2 → 1.0 — growing transients as fallback).
///
/// THE PAYOFF — 80 ms settle → the contract dims 10 % → the "SIGNED" stamp
/// (Bebas, vermilion, −8°, stamp frame) SLAMS in, scale 4 → 1 in 250 ms on an
/// ACCELERATING curve (a stamp speeds INTO impact, never eases out) → at
/// impact: `.rigid` + the card shakes ~6 px on a decaying spring + a 1-frame
/// 10 % vermilion flash → `.success` at +200 ms → "Signed · [date]" lands →
/// Continue slides up at +600 ms. The stamp sits at the BOTTOM of the card,
/// under the baseline — never on the stroke.
///
/// `onSign` (checkpoint 1: player + ContractSnapshot + advance) fires on the
/// Continue tap — the payoff beat lives entirely in this screen.
struct ContractScreen: View {
    let startingOVR: Int
    let rank: Rank
    let projectedOVR: Int
    let projectedRank: Rank
    let date: Date
    let durationDays: Int
    let hasSignature: Bool
    /// The strokes live in the VM (batch #12): the paywall's X recreates this
    /// screen, and a signed contract must come back with its mark intact.
    @Binding var strokes: [[CGPoint]]
    let onSign: () -> Void
    let onSignatureStroke: () -> Void
    let onSignatureCleared: () -> Void
    /// Fires when the hold completes — the VM remembers the seal across the
    /// paywall round trip.
    var onSealed: () -> Void = {}
    /// Re-entry from the paywall's X (and DEBUG previews): poses the sealed end
    /// state cold — stamp posed, Continue up, nothing replays.
    var startsSealed = false

    @State private var isDrawing = false
    @State private var revealed = false
    @State private var sealed = false
    /// The hold's fill fraction — mirrors the clock via `onHoldChange`.
    @State private var holdFill: CGFloat = 0
    // Payoff sequence.
    @State private var contractDimmed = false
    @State private var stampShown = false
    @State private var shakePhase: CGFloat = 0
    @State private var flashOn = false
    @State private var signedLineShown = false
    @State private var ctaVisible = false

    private static let signatureDelay: TimeInterval = 0.2
    private static let canvasHeight: CGFloat = 96
    // The stamp sequence, spec beats (2026-07-22).
    private static let settleBeat: TimeInterval = 0.08
    private static let stampSlam: TimeInterval = 0.25
    private static let stampScaleFrom: CGFloat = 4
    private static let stampAngle: Double = -8
    private static let shakeTravel: CGFloat = 6
    private static let shakeDuration: TimeInterval = 0.35
    private static let flashOpacity: Double = 0.1
    private static let flashBeat: TimeInterval = 0.05
    private static let successBeat: TimeInterval = 0.2
    private static let ctaBeat: TimeInterval = 0.6
    private static let dimOpacity: Double = 0.1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — the bar renders at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    recapCard
                        .padding(.top, 32)

                    signatureCard
                        .padding(.top, 16)

                    Spacer(minLength: 100)
                }
            }
            // His finger is drawing, not scrolling: the canvas wins while it's down.
            .scrollDisabled(isDrawing)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { cta }
        .onAppear { runIntro() }
    }

    // MARK: - Recap (one compact card — the signature is the dominant element)

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            recapRow(label: "WHERE YOU ARE",
                     value: "OVR \(startingOVR) — \(rank.displayName)",
                     color: FudoColor.textPrimary)
            recapDivider
            // Cream = the present, vermillon = the future. Same grammar as
            // OB 10 vs OB 13.
            recapRow(label: "WHERE YOU'RE GOING",
                     value: "OVR ~\(projectedOVR) — \(projectedRank.displayName), on \(OnboardingCopy.longDate(date))",
                     color: FudoColor.accent)
            recapDivider
            recapRow(label: "THE TERMS",
                     value: "Daily check-in · No zero days · \(durationDays) days",
                     color: FudoColor.textPrimary)
        }
        .padding(.vertical, 4)
        .background { card.fill(FudoColor.bgCard) }
        .overlay { card.strokeBorder(FudoColor.border, lineWidth: 1) }
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard, value: revealed)
    }

    private func recapRow(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .fudoFont(.label(10, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Text(value)
                .fudoFont(.body(15, weight: .semibold))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FudoSpacing.cardPadding)
        .padding(.vertical, 10)
    }

    private var recapDivider: some View {
        Rectangle()
            .fill(FudoColor.border)
            .frame(height: 1)
            .padding(.horizontal, FudoSpacing.cardPadding)
    }

    // MARK: - Signature (the dominant card)

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("I COMMIT TO THE PROTOCOL")
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)

                Spacer(minLength: 8)

                // Tester batch #1: a botched stroke needed a way out — clearing
                // wipes the mark AND revokes the fact of it (the CTA dies again).
                // Gone once sealed: a stamped contract is one-way.
                if !sealed && (hasSignature || !strokes.isEmpty) {
                    Button {
                        Haptics.light()
                        strokes = []
                        onSignatureCleared()
                    } label: {
                        Text("Clear")
                            .fudoFont(.caption(12, weight: .semibold))
                            .foregroundStyle(FudoColor.textSecondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .animation(AppAnimation.standard, value: hasSignature)
            .animation(AppAnimation.standard, value: sealed)

            SignatureCanvas(strokes: $strokes, isDrawing: $isDrawing,
                            onStrokeEnded: onSignatureStroke)
                .frame(height: Self.canvasHeight)
                .padding(.top, 8)
                // The stroke freezes at the seal — the mark is made.
                .allowsHitTesting(!sealed)
                .overlay {
                    if strokes.isEmpty && !hasSignature {
                        Text("Sign with your finger")
                            .fudoFont(.caption(13))
                            .foregroundStyle(FudoColor.textSecondary.opacity(0.7))
                            .allowsHitTesting(false)
                    }
                }

            // The baseline — a contract signs ON a line. Everything below it is
            // stamp territory: the mark above is never touched.
            Rectangle()
                .fill(FudoColor.border)
                .frame(height: 1)

            // The footer: date on the left, the SIGNED stamp slamming in on the
            // right — BELOW the baseline, clear of the stroke by construction.
            HStack(alignment: .center) {
                Text("Signed · \(OnboardingCopy.longDate(.now))")
                    .fudoFont(.caption(12))
                    .foregroundStyle(FudoColor.textSecondary)
                    .opacity(signedLineShown ? 1 : 0)
                    .animation(AppAnimation.standard, value: signedLineShown)

                Spacer(minLength: 8)

                if stampShown {
                    stamp
                }
            }
            .frame(minHeight: 44)
            .padding(.top, 6)
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .background { card.fill(FudoColor.bgCard) }
        // The payoff dim: the paper darkens 10 % so the stamp reads as INK.
        .overlay {
            card.fill(Color.black.opacity(contractDimmed ? Self.dimOpacity : 0))
                .allowsHitTesting(false)
        }
        // 1-frame vermilion flash at stamp impact.
        .overlay {
            card.fill(FudoColor.accent.opacity(flashOn ? Self.flashOpacity : 0))
                .allowsHitTesting(false)
        }
        .overlay { card.strokeBorder(FudoColor.border, lineWidth: 1) }
        .modifier(StampShakeEffect(travel: Self.shakeTravel, phase: shakePhase))
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Self.signatureDelay), value: revealed)
    }

    /// The rubber stamp: Bebas, vermilion, tilted, double-framed. Slams in
    /// scale 4 → 1 on an easeIn — accelerating INTO the impact.
    private var stamp: some View {
        Text("SIGNED")
            .fudoFont(.onboardingDisplay(24))
            .foregroundStyle(FudoColor.accent)
            .kerning(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(FudoColor.accent, lineWidth: 2)
            }
            .rotationEffect(.degrees(Self.stampAngle))
            .transition(.scale(scale: Self.stampScaleFrom)
                .combined(with: .opacity)
                .animation(.easeIn(duration: Self.stampSlam)))
            .allowsHitTesting(false)
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    // MARK: - CTA

    /// State 1: the 2.5 s hold — no ring: the capsule itself fills vermilion
    /// left to right while the glow builds (determinate, mirrors the clock),
    /// haptics ramp continuously underneath. State 2: HOLD TO SIGN is gone;
    /// Continue slides up once the stamp landed.
    @ViewBuilder private var cta: some View {
        Group {
            if sealed {
                Button(action: onSign) {
                    Text("Continue")
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: FudoSpacing.ctaHeight)
                        .background { Capsule().fill(FudoColor.accent) }
                }
                .buttonStyle(.plain)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 24)
                .allowsHitTesting(ctaVisible)
            } else {
                Text("HOLD TO SIGN")
                    .fudoFont(.headline())
                    .kerning(1)
                    .foregroundStyle(hasSignature ? FudoColor.textPrimary : FudoColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { holdCapsule }
                    .holdToConfirm(in: Capsule(), duration: OnboardingMetrics.signHoldDuration,
                                   completionHaptic: .heavy,
                                   showsRing: false, hapticStyle: .ramp,
                                   onHoldChange: { holding in
                                       if holding {
                                           withAnimation(.linear(duration: OnboardingMetrics.signHoldDuration)) {
                                               holdFill = 1
                                           }
                                       } else {
                                           withAnimation(.easeOut(duration: HoldToConfirmMetrics.rewindDuration)) {
                                               holdFill = 0
                                           }
                                       }
                                   }) {
                        seal()
                    }
                    .disabled(!hasSignature)
                    .animation(AppAnimation.standard, value: hasSignature)
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
        .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
    }

    /// The dark capsule with the determinate vermilion fill sweeping through it.
    /// The glow rides the fill — brighter as the seal gets closer. Deliberate
    /// exception to the no-shadow card rule: this is a hold payoff, not a card.
    private var holdCapsule: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(FudoColor.bgCard)

            GeometryReader { geometry in
                Rectangle()
                    .fill(FudoColor.accent)
                    .frame(width: geometry.size.width * holdFill)
            }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(hasSignature ? FudoColor.accent.opacity(0.5)
                                                : FudoColor.border,
                                   lineWidth: 1)
        }
        .shadow(color: FudoColor.accent.opacity(0.55 * holdFill),
                radius: 18 * holdFill)
    }

    // MARK: - Sequence

    private func runIntro() {
        if startsSealed {
            revealed = true
            sealed = true
            contractDimmed = true
            stampShown = true
            signedLineShown = true
            ctaVisible = true
            return
        }
        revealed = true
    }

    /// The stamp sequence — spec beats, one-way. `sealed` flips first (stroke
    /// frozen, Clear gone, HOLD CTA retired), then the theater plays.
    private func seal() {
        guard !sealed else { return }
        withAnimation(AppAnimation.standard) { sealed = true }
        onSealed()

        Task { @MainActor in
            // Settle, then the paper darkens under the incoming stamp.
            try? await Task.sleep(for: .seconds(Self.settleBeat))
            withAnimation(.easeOut(duration: Self.stampSlam)) { contractDimmed = true }

            // The slam — its easeIn transition accelerates INTO the impact.
            withAnimation { stampShown = true }
            try? await Task.sleep(for: .seconds(Self.stampSlam))

            // Impact: rigid hit, 1-frame flash, decaying shake.
            Haptics.rigid()
            flashOn = true
            withAnimation(.linear(duration: Self.shakeDuration)) { shakePhase = 1 }
            try? await Task.sleep(for: .seconds(Self.flashBeat))
            flashOn = false

            try? await Task.sleep(for: .seconds(Self.successBeat - Self.flashBeat))
            Haptics.success()
            withAnimation(AppAnimation.standard) { signedLineShown = true }

            try? await Task.sleep(for: .seconds(Self.ctaBeat - Self.successBeat))
            withAnimation(.easeOut(duration: 0.5)) { ctaVisible = true }
        }
    }
}

/// The impact shake: a decaying horizontal oscillation (~3 swings), driven by
/// `phase` 0 → 1. Amplitude dies linearly — a slammed stamp, not a buzz.
private struct StampShakeEffect: GeometryEffect {
    var travel: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard phase > 0, phase < 1 else { return ProjectionTransform(.identity) }
        let decay = 1 - phase
        let x = travel * sin(phase * .pi * 6) * decay
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

#if DEBUG
/// 43 → ~78 on the canonical run. The rank reads WARRIOR at 78 — the frame's
/// "Master" is a bug (Master opens at 80). State 1: no price anywhere.
private struct ContractPreviewHost: View {
    @State var strokes: [[CGPoint]] = []
    var hasSignature = false
    var startsSealed = false
    var ovr = 43
    var days = 30

    var body: some View {
        OnboardingPreviewChrome {
            ContractScreen(startingOVR: ovr, rank: .novice, projectedOVR: 78,
                           projectedRank: .warrior,
                           date: Calendar.current.date(byAdding: .day, value: days - 1, to: .now) ?? .now,
                           durationDays: days, hasSignature: hasSignature,
                           strokes: $strokes,
                           onSign: {}, onSignatureStroke: {}, onSignatureCleared: {},
                           startsSealed: startsSealed)
        }
    }
}

#Preview("OB 17 — state 1 (unsigned)") {
    ContractPreviewHost()
}

/// Signed, hold not done: CTA live, STILL no price. The fill + ramp only exist
/// under a finger — the feel is a device check.
#Preview("OB 17 — state 1 (signed, pre-hold)") {
    ContractPreviewHost(hasSignature: true, ovr: 45)
}

/// State 2 — sealed (the paywall-X return state): dimmed paper, SIGNED stamp
/// under the baseline, Continue up, nothing replays. 90 days from the ceiling.
#Preview("OB 17 — state 2 (stamped, 90 days)") {
    ContractPreviewHost(hasSignature: true, startsSealed: true, ovr: 50, days: 90)
}
#endif
