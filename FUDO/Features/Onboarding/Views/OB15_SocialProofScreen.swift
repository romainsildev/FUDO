import StoreKit
import SwiftUI

/// OB 15 — the peak. He just made his first gesture and the flame is lit; the
/// Apple prompt lands on the highest emotion of the funnel — the only moment a
/// 5-star is sincere.
///
/// Batch #8: one full-screen visual beat, the DUEL TRACK — the report's own
/// data-viz grammar (grey = the others, vermilion = him). A thin line draws
/// left to right: grey from day 0 to the day-4 tick where MOST MEN stop (their
/// dots drop off the line), then the stroke takes over in vermilion and runs
/// to the far terminus: YOU — DAY N, his real chosen duration. The draw plays
/// ONCE per funnel run (one-shot pattern); the review prompt fires AFTER the
/// track lands — the visual peak first, the ask second.
///
/// Honesty intact (batch #6): no ratings, no stars, no names, no "our users"
/// numbers. The tick positions are display geometry, not a scale — the labels
/// carry the real numbers.
struct SocialProofScreen: View {
    let flags: OnboardingFlags
    /// The duration HE picked at 11a — track terminus + subline print it.
    let durationDays: Int
    /// One-shot pattern: the draw's "played" fact lives in the VM — a back
    /// re-entry re-creates this view (@State resets) and must pose the
    /// finished track cold, never replay it.
    let hasPlayed: Bool
    let onPlayed: () -> Void
    let onAdvance: () -> Void

    /// The NATIVE prompt only — never a custom rate-us modal (known-pitfalls list).
    @Environment(\.requestReview) private var requestReview

    @State private var revealed = false
    @State private var grayDrawn = false
    @State private var dotsDropped = false
    @State private var redDrawn = false
    @State private var footerVisible = false

    private static let grayDraw: TimeInterval = 0.5
    private static let pause: TimeInterval = 0.3
    private static let redDraw: TimeInterval = 0.7

    var body: some View {
        OnboardingScaffold(step: .socialProof, canAdvance: true,
                           centersVertically: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                heroStat
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)
                    .animation(AppAnimation.standard, value: revealed)

                DuelTrackView(durationDays: durationDays,
                              grayDrawn: grayDrawn, dotsDropped: dotsDropped,
                              redDrawn: redDrawn,
                              grayDuration: Self.grayDraw, redDuration: Self.redDraw)
                    .padding(.top, 44)

                // No caption below (Romain): hook + track + subline, nothing else.
                counterpoint
                    .padding(.top, 36)
                    .opacity(footerVisible ? 1 : 0)
                    .offset(y: footerVisible ? 0 : 8)
            }
        }
        .task { await run() }
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

    // MARK: - Sequence

    /// Draw once, then ask: grey draws to the day-4 tick, the quitters drop,
    /// the vermilion takes over (medium haptic as it crosses the tick), the
    /// footer lands — and only THEN the review prompt (the peak, never before).
    private func run() async {
        revealed = true
        if hasPlayed {
            // Re-entry: everything posed cold, no draw, no haptic.
            grayDrawn = true
            dotsDropped = true
            redDrawn = true
            footerVisible = true
            await askForReview()
            return
        }
        onPlayed()
        withAnimation(.easeInOut(duration: Self.grayDraw)) { grayDrawn = true }
        try? await Task.sleep(for: .seconds(Self.grayDraw))
        guard !Task.isCancelled else { return }   // exactly-once, batch #3 pattern
        withAnimation(AppAnimation.standard) { dotsDropped = true }
        try? await Task.sleep(for: .seconds(Self.pause))
        guard !Task.isCancelled else { return }
        Haptics.medium()   // the stroke crosses the day-4 tick and keeps going
        withAnimation(.easeOut(duration: Self.redDraw)) { redDrawn = true }
        try? await Task.sleep(for: .seconds(Self.redDraw))
        guard !Task.isCancelled else { return }
        withAnimation(AppAnimation.standard) { footerVisible = true }
        await askForReview()
    }

    /// iOS rate-limits its own sheet; the flag keeps US from asking twice in one
    /// install. It survives a DEBUG replay on purpose.
    private func askForReview() async {
        guard !flags.reviewPrompted else { return }
        try? await Task.sleep(for: .seconds(OnboardingMetrics.reviewPromptDelay))
        guard !Task.isCancelled else { return }
        flags.reviewPrompted = true
        requestReview()
    }
}

// MARK: - The duel track

/// The screen's hero: one thin line, two strokes. Grey runs day 0 → the day-4
/// tick and stops dead (label MOST MEN above, their dots dropping off just
/// past it); vermilion takes over at the tick and runs to the terminus dot
/// (label YOU — DAY N). The tick sits at a fixed display fraction — a real
/// day-scale would crush day 4 against the left edge on a 120-day run; the
/// labels carry the true numbers (honesty guard).
private struct DuelTrackView: View {
    let durationDays: Int
    let grayDrawn: Bool
    let dotsDropped: Bool
    let redDrawn: Bool
    let grayDuration: TimeInterval
    let redDuration: TimeInterval

    private static let lineHeight: CGFloat = 5
    private static let tickFraction: CGFloat = 0.30
    private static let dropDotCount = 3
    private static let dropDotSize: CGFloat = 8
    private static let terminusSize: CGFloat = 12
    private static let labelGap: CGFloat = 10
    private static let dropDepth: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height / 2
            let tickX = width * Self.tickFraction

            ZStack(alignment: .leading) {
                // Grey: day 0 → day 4, stops dead on the tick.
                Capsule()
                    .fill(FudoColor.textSecondary)
                    .frame(width: tickX, height: Self.lineHeight)
                    .scaleEffect(x: grayDrawn ? 1 : 0.001, anchor: .leading)
                    .position(x: tickX / 2, y: midY)

                // The tick where most men stop.
                RoundedRectangle(cornerRadius: 1)
                    .fill(FudoColor.textSecondary)
                    .frame(width: 2, height: 14)
                    .position(x: tickX, y: midY)
                    .opacity(grayDrawn ? 1 : 0)

                Text(SocialProofCopy.trackAverageLabel)
                    .fudoFont(.label(13, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(FudoColor.textSecondary)
                    .position(x: tickX, y: midY - Self.labelGap - 14)
                    .opacity(grayDrawn ? 1 : 0)

                // The quitters: dots that drop off the line just past the tick.
                ForEach(0..<Self.dropDotCount, id: \.self) { index in
                    Circle()
                        .fill(FudoColor.textSecondary)
                        .frame(width: Self.dropDotSize, height: Self.dropDotSize)
                        .position(x: tickX + 16 + CGFloat(index) * 14, y: midY)
                        .offset(y: dotsDropped ? Self.dropDepth : 4)
                        .opacity(dotsDropped ? 0 : (grayDrawn ? 0.7 : 0))
                        .animation(AppAnimation.standard.delay(Double(index) * 0.08),
                                   value: dotsDropped)
                }

                // Vermilion: takes over at the tick, runs to the end of the screen.
                Capsule()
                    .fill(FudoColor.accent)
                    .frame(width: width - tickX - Self.terminusSize / 2,
                           height: Self.lineHeight)
                    .scaleEffect(x: redDrawn ? 1 : 0.001, anchor: .leading)
                    .position(x: tickX + (width - tickX - Self.terminusSize / 2) / 2, y: midY)

                // Terminus: him, still on the line, at HIS day.
                Circle()
                    .fill(FudoColor.accent)
                    .frame(width: Self.terminusSize, height: Self.terminusSize)
                    .position(x: width - Self.terminusSize / 2, y: midY)
                    .opacity(redDrawn ? 1 : 0)
                    .animation(.easeOut(duration: 0.2).delay(redDrawn ? redDuration * 0.8 : 0),
                               value: redDrawn)

            }
        }
        .frame(height: 76)
        // Trailing-anchored so a long "YOU — DAY 120" never bleeds off-screen.
        .overlay(alignment: .topTrailing) {
            Text(SocialProofCopy.trackYouLabel(days: durationDays))
                .fudoFont(.label(13, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(FudoColor.accent)
                .opacity(redDrawn ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(redDrawn ? redDuration * 0.8 : 0),
                           value: redDrawn)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Most men quit by day 4. You signed for \(durationDays) days.")
    }
}

#if DEBUG
/// The draw only plays live — the canvas poses the finished track (hasPlayed).
/// No stars, no "4.8", no names (batch #6). Flags carry reviewPrompted = true:
/// the canvas must not fire the system review sheet.
#Preview("OB 15 — duel track (60 days, played)") {
    let flags = OnboardingPreviewFactory.flags("preview.socialProof")
    flags.reviewPrompted = true
    return OnboardingPreviewChrome {
        SocialProofScreen(flags: flags, durationDays: 60,
                          hasPlayed: true, onPlayed: {}, onAdvance: {})
    }
}

/// Live draw-in — run the canvas to see the sequence once.
#Preview("OB 15 — duel track (120 days, live)") {
    let flags = OnboardingPreviewFactory.flags("preview.socialProof120")
    flags.reviewPrompted = true
    return OnboardingPreviewChrome {
        SocialProofScreen(flags: flags, durationDays: 120,
                          hasPlayed: false, onPlayed: {}, onAdvance: {})
    }
}
#endif
