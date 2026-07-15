import SwiftUI

/// OB 17 — the sunk cost, made physical. He composed his protocol, saw his date,
/// made his gesture; here he SIGNS, with his finger, on a black screen. Not a
/// checkbox: a mark that's his, then a 2.5 s hold. After this, quitting isn't
/// "not starting" — it's going back on his word. And the price lands AFTER the
/// signature, once the value is already banked.
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

    @State private var strokes: [[CGPoint]] = []
    @State private var isDrawing = false
    @State private var revealed = false

    private static let cardStagger: TimeInterval = 0.06
    private static let signatureDelay: TimeInterval = 0.3
    private static let priceDelay: TimeInterval = 0.5
    private static let signatureCardHeight: CGFloat = 130
    private static let canvasHeight: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full bar, no chevron: this is the end of the persuasion tunnel.
            OnboardingProgressBar(fraction: OnboardingStep.contract.progressFraction)
                .padding(.top, 8)
                .frame(height: 24)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("THE CONTRACT")
                        .fudoFont(.label(13, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FudoColor.accent)
                        .padding(.top, 32)

                    recapCards
                        .padding(.top, 16)

                    signatureCard
                        .padding(.top, 14)

                    Text(PricingCopy.hook)
                        .fudoFont(.title(24, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                        .padding(.top, 26)
                        .opacity(revealed ? 1 : 0)
                        .animation(AppAnimation.standard.delay(Self.priceDelay), value: revealed)

                    Text(PricingCopy.detail)
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                        .lineSpacing(2)
                        .padding(.top, 8)
                        .opacity(revealed ? 1 : 0)
                        .animation(AppAnimation.standard.delay(Self.priceDelay), value: revealed)

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
        .onAppear { revealed = true }
    }

    // MARK: - Recap

    private var recapCards: some View {
        VStack(spacing: 10) {
            recapCard(label: "WHERE YOU ARE",
                      value: "OVR \(startingOVR) — \(rank.displayName)",
                      // Cream = the present, vermillon = the future. Same grammar
                      // as OB 10 vs OB 13.
                      color: FudoColor.textPrimary, index: 0)
            recapCard(label: "WHERE YOU'RE GOING",
                      value: "OVR ~\(projectedOVR) — \(projectedRank.displayName), on \(OnboardingCopy.longDate(date))",
                      color: FudoColor.accent, index: 1)
            recapCard(label: "THE TERMS",
                      value: "Daily check-in · No zero days · \(durationDays) days",
                      color: FudoColor.textPrimary, index: 2)
        }
    }

    private func recapCard(label: String, value: String, color: Color, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Text(value)
                .fudoFont(.headline(17))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPadding)
        .background { card.fill(FudoColor.bgCard) }
        .overlay { card.strokeBorder(FudoColor.border, lineWidth: 1) }
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Double(index) * Self.cardStagger), value: revealed)
    }

    // MARK: - Signature

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("I COMMIT TO THE PROTOCOL")
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            SignatureCanvas(strokes: $strokes, isDrawing: $isDrawing,
                            onStrokeEnded: onSignatureStroke)
                .frame(height: Self.canvasHeight)
                .padding(.top, 6)

            Rectangle()
                .fill(FudoColor.border)
                .frame(height: 1)

            Text("Signed · today")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 6)
                .opacity(hasSignature ? 1 : 0)
                .animation(AppAnimation.standard, value: hasSignature)
        }
        .frame(maxWidth: .infinity, minHeight: Self.signatureCardHeight, alignment: .leading)
        .padding(FudoSpacing.cardPadding)
        .background { card.fill(FudoColor.bgCard) }
        .overlay { card.strokeBorder(FudoColor.border, lineWidth: 1) }
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(Self.signatureDelay), value: revealed)
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    // MARK: - CTA

    /// 2.5 s and a `.heavy` seal — this hold is not a checklist tick, it binds.
    /// The cream ring is the same fix as the setup CTAs: vermillon on vermillon
    /// is an invisible ring.
    private var cta: some View {
        Text("HOLD TO SIGN")
            .fudoFont(.headline())
            .kerning(1)
            .foregroundStyle(hasSignature ? FudoColor.textPrimary : FudoColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: FudoSpacing.ctaHeight)
            .background { Capsule().fill(hasSignature ? FudoColor.accent : FudoColor.bgCard) }
            .overlay {
                Capsule().strokeBorder(hasSignature ? Color.clear : FudoColor.border, lineWidth: 1)
            }
            .holdToConfirm(in: Capsule(), duration: OnboardingMetrics.signHoldDuration,
                           completionHaptic: .heavy, ringColor: FudoColor.textPrimary) {
                onSign()
            }
            .disabled(!hasSignature)
            .animation(AppAnimation.standard, value: hasSignature)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
    }
}

#if DEBUG
/// 43 → ~78 on the canonical run. The rank reads WARRIOR at 78 — the frame's
/// "Master" is a bug (Master opens at 80).
#Preview("OB 17 — contract (unsigned)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 43, rank: .novice, projectedOVR: 78,
                       projectedRank: .warrior,
                       date: Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now,
                       durationDays: 30, hasSignature: false,
                       onSign: {}, onSignatureStroke: {})
    }
}

/// Signed: "Signed · today" appears and the CTA goes live. The stroke itself only
/// exists under a finger — draw it in the canvas by dragging.
#Preview("OB 17 — contract (signed)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 45, rank: .novice, projectedOVR: 79,
                       projectedRank: .warrior,
                       date: Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now,
                       durationDays: 30, hasSignature: true,
                       onSign: {}, onSignatureStroke: {})
    }
}

/// Hardcore 90 from the ceiling — the longest terms line the card must hold.
#Preview("OB 17 — contract (Hardcore 90)") {
    OnboardingPreviewChrome {
        ContractScreen(startingOVR: 50, rank: .disciple, projectedOVR: 96,
                       projectedRank: .sensei,
                       date: Calendar.current.date(byAdding: .day, value: 89, to: .now) ?? .now,
                       durationDays: 90, hasSignature: true,
                       onSign: {}, onSignatureStroke: {})
    }
}
#endif
