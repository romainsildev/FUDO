import SwiftUI

/// OB 06 — the AHA, under a minute from opening. He isn't reading a statistic:
/// he's reading HIS OWN multiplication. Redesigned hierarchy (copy pass
/// 2026-07-16): FOUR elements, no more — a short 45 % setup line, the giant
/// Bebas vermillon number (the only strong element), one fused line under it,
/// and the pivot a beat later.
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

    /// The fused line lands with the number's end; the pivot one beat later.
    private static let fusedDelay: TimeInterval = OnboardingMetrics.countUpDuration
    private static let pivotDelay: TimeInterval = OnboardingMetrics.countUpDuration + 0.55

    var body: some View {
        OnboardingScaffold(step: .shockStat, canAdvance: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                // 1 — the setup, secondary at 45 %: it points, it doesn't punch.
                Text(OnboardingCopy.shockLead(shock: shock))
                    .fudoFont(.body(17, weight: .medium))
                    .foregroundStyle(FudoColor.textPrimary)
                    .opacity(0.45)

                // 2 — the blow.
                number
                    .padding(.top, 10)

                // 3 — one line, his wound fused in. No separate recut paragraph.
                Text(OnboardingCopy.shockOfYourLife(pain: pain))
                    .fudoFont(.title(20, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.fusedDelay), value: revealed)

                // 4 — the pivot, small, one beat after the hit.
                Text(OnboardingCopy.shockPivot)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 28)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.pivotDelay), value: revealed)
            }
        }
        .onboardingWarmWash()
        .task { await runCountUp() }
    }

    /// The count-up re-formats through ShockMath's own rule — "1.9 YEARS" or
    /// "205 DAYS", never two spellings of one number. Bebas display, vermillon:
    /// the one strong element of the screen.
    private var number: some View {
        CountUpText(value: counted) { ShockMath.headline(for: max(0, $0)).uppercased() }
            .fudoFont(.onboardingDisplay(72))
            .foregroundStyle(FudoColor.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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
