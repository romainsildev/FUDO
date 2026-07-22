import SwiftUI

/// OB 17 (batch #6 recut) — the sunk cost, made physical and SEQUENCED right.
///
/// STATE 1 — before the seal: the recap compacted into one card (GOING keeps
/// the vermilion), then the DOMINANT element: the signature card — tracked
/// commit label, a real baseline, "Sign with your finger". NO price anywhere
/// on screen: the price before the signature was the exact inversion of the
/// sunk-cost spec.
///
/// STATE 2 — the hold completes (2.5 s, progressive haptics, `.heavy` seal):
/// a SOBER payoff (device pass, Romain — the ensō stamp dirtied the stroke and
/// is gone): the signature freezes, the card's border pulses vermilion ONCE
/// (~0.5 s) and comes back, nothing lands ON the mark. Then Continue slides up
/// where HOLD TO SIGN used to live.
///
/// NO price on this screen at all (Romain's override of the old sunk-cost spec):
/// the price lives at the PAYWALL only — the kebab line waits in `PricingCopy`
/// for Session 6.
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
    let onSign: () -> Void
    let onSignatureStroke: () -> Void
    let onSignatureCleared: () -> Void
    /// DEBUG previews only — renders state 2 (stamp, price, Continue).
    var startsSealed = false

    @State private var strokes: [[CGPoint]] = []
    @State private var isDrawing = false
    @State private var revealed = false
    @State private var sealed = false
    @State private var borderPulse = false
    @State private var ctaVisible = false

    private static let signatureDelay: TimeInterval = 0.2
    private static let canvasHeight: CGFloat = 96
    /// One border pulse out and back, then the CTA — whole payoff ≈ 0.9 s.
    private static let pulseDuration: TimeInterval = 0.25
    private static let ctaDelay: TimeInterval = 0.35

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

            // The baseline — a contract signs ON a line.
            Rectangle()
                .fill(FudoColor.border)
                .frame(height: 1)

            Text("Signed · today")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 8)
                .opacity(hasSignature ? 1 : 0)
                .animation(AppAnimation.standard, value: hasSignature)
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .background { card.fill(FudoColor.bgCard) }
        // The whole payoff: the border flashes vermilion once and comes back.
        .overlay {
            card.strokeBorder(borderPulse ? FudoColor.accent : FudoColor.border,
                              lineWidth: 1)
        }
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Self.signatureDelay), value: revealed)
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    // MARK: - CTA

    /// State 1: the 2.5 s hold, `.heavy` seal — this is not a checklist tick,
    /// it binds. Cream ring: vermillon on vermillon is an invisible ring.
    /// State 2: HOLD TO SIGN is gone; Continue slides up once the price landed.
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
                    .background { Capsule().fill(hasSignature ? FudoColor.accent : FudoColor.bgCard) }
                    .overlay {
                        Capsule().strokeBorder(hasSignature ? Color.clear : FudoColor.border,
                                               lineWidth: 1)
                    }
                    .holdToConfirm(in: Capsule(), duration: OnboardingMetrics.signHoldDuration,
                                   completionHaptic: .heavy, ringColor: FudoColor.textPrimary) {
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

    // MARK: - Sequence

    private func runIntro() {
        if startsSealed {
            revealed = true
            sealed = true
            ctaVisible = true
            return
        }
        revealed = true
    }

    /// The hold's `.heavy` already fired — the payoff stays sober: freeze, one
    /// border pulse, Continue. One-way: the HOLD CTA is gone, nothing replays.
    private func seal() {
        guard !sealed else { return }
        withAnimation(AppAnimation.standard) { sealed = true }
        withAnimation(.easeInOut(duration: Self.pulseDuration)) { borderPulse = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.pulseDuration))
            withAnimation(.easeInOut(duration: Self.pulseDuration)) { borderPulse = false }
            try? await Task.sleep(for: .seconds(Self.ctaDelay))
            withAnimation(.easeOut(duration: 0.5)) { ctaVisible = true }
        }
    }
}

#if DEBUG
/// 43 → ~78 on the canonical run. The rank reads WARRIOR at 78 — the frame's
/// "Master" is a bug (Master opens at 80). State 1: no price anywhere.
#Preview("OB 17 — state 1 (unsigned)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 43, rank: .novice, projectedOVR: 78,
                       projectedRank: .warrior,
                       date: Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now,
                       durationDays: 30, hasSignature: false,
                       onSign: {}, onSignatureStroke: {}, onSignatureCleared: {})
    }
}

/// Signed, hold not done: "Signed · today" up, CTA live, STILL no price. The
/// hold's ring only exists under a finger — the feel is a device check.
#Preview("OB 17 — state 1 (signed, pre-hold)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 45, rank: .novice, projectedOVR: 79,
                       projectedRank: .warrior,
                       date: Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now,
                       durationDays: 30, hasSignature: true,
                       onSign: {}, onSignatureStroke: {}, onSignatureCleared: {})
    }
}

/// State 2 — sealed, SOBER: frozen mark, no stamp, NO price anywhere (the price
/// lives at the paywall only), Continue up. Monk Mode 90 from the ceiling —
/// the longest terms line the card must hold.
#Preview("OB 17 — state 2 (sealed, 90 days)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 50, rank: .disciple, projectedOVR: 96,
                       projectedRank: .sensei,
                       date: Calendar.current.date(byAdding: .day, value: 89, to: .now) ?? .now,
                       durationDays: 90, hasSignature: true,
                       onSign: {}, onSignatureStroke: {}, onSignatureCleared: {},
                       startsSealed: true)
    }
}
#endif
