import StoreKit
import SwiftUI

/// OB 15 — the peak. He just made his first gesture and the flame is lit; we show
/// him he isn't alone and we ask for the rating. The Apple prompt lands on the
/// highest emotion of the funnel — the only moment a 5-star is sincere.
///
/// D4 (Romain, 2026-07-15): no rating line and no stars. Both ARE a claim, and
/// we haven't earned one yet. The testimonials carry the screen — and they are
/// placeholders until real, consented tester quotes replace them (SocialProofCopy).
struct SocialProofScreen: View {
    let flags: OnboardingFlags
    let onAdvance: () -> Void

    /// The NATIVE prompt only — never a custom rate-us modal (known-pitfalls list).
    @Environment(\.requestReview) private var requestReview

    @State private var revealed = false

    private static let cardStagger: TimeInterval = 0.08

    var body: some View {
        OnboardingScaffold(step: .socialProof, 
                           title: SocialProofCopy.proofTitle,
                           canAdvance: true, onAdvance: onAdvance) {
            VStack(spacing: 12) {
                ForEach(Array(SocialProofCopy.testimonials.enumerated()), id: \.offset) { index, item in
                    testimonial(quote: item.quote, author: item.author)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 10)
                        .animation(AppAnimation.standard.delay(Double(index) * Self.cardStagger),
                                   value: revealed)
                }
            }
        }
        .task { await askForReview() }
    }

    private func testimonial(quote: String, author: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\"\(quote)\"")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(author)
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    /// iOS rate-limits its own sheet; the flag keeps US from asking twice in one
    /// install. It survives a DEBUG replay on purpose.
    private func askForReview() async {
        revealed = true
        guard !flags.reviewPrompted else { return }
        try? await Task.sleep(for: .seconds(OnboardingMetrics.reviewPromptDelay))
        flags.reviewPrompted = true
        requestReview()
    }
}

#if DEBUG
/// No stars, no "4.8" — D4. The canvas is also where the placeholder testimonials
/// stay visible: they must be replaced by real, consented tester quotes before
/// submit (docs/ONBOARDING-PLAN.md §"Le point resté ouvert").
///
/// The preview passes flags with reviewPrompted already true: the canvas must not
/// fire the system review sheet.
#Preview("OB 15 — social proof") {
    let flags = OnboardingPreviewFactory.flags("preview.socialProof")
    flags.reviewPrompted = true
    return OnboardingPreviewChrome {
        SocialProofScreen(flags: flags, onAdvance: {})
    }
}
#endif
