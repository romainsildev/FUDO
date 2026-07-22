import StoreKit
import SwiftUI

/// OB 15 — the peak. He just made his first gesture and the flame is lit; the
/// Apple prompt lands on the highest emotion of the funnel — the only moment a
/// 5-star is sincere.
///
/// Batch #6: the named testimonials are GONE (invented people + invented OVRs
/// = App Review 2.3.1 exposure). What replaced them is HONEST hardness: a blunt
/// non-nominative stat ("most men are done by day 4" — the D4-acted phrasing),
/// his own chosen duration turned back at him, and the frame line. No ratings,
/// no stars, no first names, no "our users" numbers.
struct SocialProofScreen: View {
    let flags: OnboardingFlags
    /// The duration HE picked at 11a — the counterpoint prints the real number.
    let durationDays: Int
    let onAdvance: () -> Void

    /// The NATIVE prompt only — never a custom rate-us modal (known-pitfalls list).
    @Environment(\.requestReview) private var requestReview

    @State private var revealed = false

    private static let counterDelay: TimeInterval = 0.35
    private static let frameDelay: TimeInterval = 0.6

    var body: some View {
        OnboardingScaffold(step: .socialProof, canAdvance: true,
                           centersVertically: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                heroStat
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)
                    .animation(AppAnimation.standard, value: revealed)

                counterpoint
                    .padding(.top, 28)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)
                    .animation(AppAnimation.standard.delay(Self.counterDelay), value: revealed)

                Text(SocialProofCopy.frameLine)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 14)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.frameDelay), value: revealed)
            }
        }
        .task { await askForReview() }
    }

    /// Bebas display, hook register (the ONLY place Bebas lives). Bicolour by
    /// segment + ONE fudoFont on the combined Text — a Font per segment kills
    /// Dynamic Type (batch #4 trap).
    private var heroStat: some View {
        (Text(SocialProofCopy.heroLead)
            .foregroundStyle(FudoColor.textPrimary)
         + Text(SocialProofCopy.heroAccent)
            .foregroundStyle(FudoColor.accent))
            .fudoFont(.onboardingDisplay(56))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var counterpoint: some View {
        (Text(SocialProofCopy.counterLead)
            .foregroundStyle(FudoColor.textPrimary)
         + Text("\(durationDays).")
            .foregroundStyle(FudoColor.accent))
            .fudoFont(.title(22, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
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
/// No stars, no "4.8", no names — the hard-stat cut (batch #6). The preview
/// passes flags with reviewPrompted already true: the canvas must not fire the
/// system review sheet.
#Preview("OB 15 — the odds (60 days)") {
    let flags = OnboardingPreviewFactory.flags("preview.socialProof")
    flags.reviewPrompted = true
    return OnboardingPreviewChrome {
        SocialProofScreen(flags: flags, durationDays: 60, onAdvance: {})
    }
}

#Preview("OB 15 — the odds (120 days)") {
    let flags = OnboardingPreviewFactory.flags("preview.socialProof120")
    flags.reviewPrompted = true
    return OnboardingPreviewChrome {
        SocialProofScreen(flags: flags, durationDays: 120, onAdvance: {})
    }
}
#endif
