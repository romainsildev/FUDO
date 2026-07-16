import SwiftUI

/// OB 06 — the AHA, under a minute from opening. He isn't reading a statistic:
/// he's reading HIS OWN multiplication. Then the pivot — we don't leave him in
/// the pain, we tell him monk mode exists exactly for this. Strict minimum on
/// screen (UX pass 2026-07-16): the giant number, one context line, the pivot.
///
/// Nothing on this screen claims a study. The number is his two answers, times
/// each other (ShockMath). That's the whole point, and it's why it survives a
/// fact-check.
struct ShockStatScreen: View {
    let shock: ShockMath.Result
    let pain: Pain
    let onAdvance: () -> Void

    @State private var counted: Double = 0
    @State private var revealed = false

    /// ONE beat after the number (UX pass 2026-07-16): everything below it fades
    /// in together. He takes the hit, then we name it — once.
    private static let afterNumberDelay: TimeInterval = OnboardingMetrics.countUpDuration

    var body: some View {
        OnboardingScaffold(step: .shockStat, 
                           title: OnboardingCopy.shockLead(shock: shock),
                           canAdvance: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                number
                Text("of your life.")
                    .fudoFont(.title(24, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)

                // The strict minimum below the number: his wound at 45 % —
                // present, never shouting — then the pivot. The 30-day stake
                // paragraph is gone (UX pass 2026-07-16: too much to read).
                VStack(alignment: .leading, spacing: 0) {
                    Text(OnboardingCopy.shockRecut(pain: pain, shock: shock))
                        .fudoFont(.body(15, weight: .medium))
                        .foregroundStyle(FudoColor.textPrimary)
                        .opacity(0.45)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    separator
                        .padding(.top, 28)

                    Text(OnboardingCopy.shockPivot)
                        .fudoFont(.body(15))
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 22)
                }
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(Self.afterNumberDelay), value: revealed)
            }
        }
        .onboardingWarmWash()
        .task { await runCountUp() }
    }

    /// The count-up re-formats through ShockMath's own rule — "1.9 years" or
    /// "205 days", never two spellings of one number.
    private var number: some View {
        CountUpText(value: counted) { ShockMath.headline(for: max(0, $0)) }
            .fudoFont(.ovr(56))
            .foregroundStyle(FudoColor.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var separator: some View {
        Rectangle()
            .fill(FudoColor.accent)
            .frame(width: 32, height: 2)
    }

    /// Sober: it climbs, it stops, it hits. No bounce, no scale — the number
    /// doesn't need help.
    private func runCountUp() async {
        revealed = true
        withAnimation(.easeOut(duration: OnboardingMetrics.countUpDuration)) {
            counted = shock.years
        }
        try? await Task.sleep(for: .seconds(OnboardingMetrics.countUpDuration))
        Haptics.medium()   // the blow lands WITH the number, not before it
    }
}

#if DEBUG
/// Three profiles, three numbers, three recuts — this screen only exists if it
/// says something different to different men.
private struct ShockPreviewHost: View {
    let draft: OnboardingDraft

    var body: some View {
        OnboardingPreviewChrome {
            if let age = draft.age, let scroll = draft.scrollTime, let pain = draft.pain {
                ShockStatScreen(shock: ShockMath.result(age: age, scroll: scroll),
                                pain: pain, onAdvance: {})
            }
        }
    }
}

/// 18-24, 4-6 h, training → "1.9 years" · "not spent training."
#Preview("OB 06 — 1.9 years (training)") {
    ShockPreviewHost(draft: .previewAnswered)
}

/// 13-17, 6 h+, doomscrolling → "4.4 years", the heaviest number the funnel says.
#Preview("OB 06 — 4.4 years (doomscrolling)") {
    ShockPreviewHost(draft: .previewHeavy)
}

/// Under 2 h → below a year, so the headline flips to DAYS ("205 days").
/// "0.6 years" would land on nobody — this is the case that proves the unit swap.
#Preview("OB 06 — 205 days (reading)") {
    ShockPreviewHost(draft: .previewLight)
}
#endif
