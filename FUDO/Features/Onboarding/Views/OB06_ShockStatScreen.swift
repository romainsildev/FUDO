import SwiftUI

/// OB 06 — the AHA, under a minute from opening. He isn't reading a statistic:
/// he's reading HIS OWN multiplication, then WATCHING it eat his life (design
/// pass 2026-07-22, Opal "years of your life" + Tim Urban grid): a short setup
/// line, the giant Bebas count-up, and a LIFE GRID — every dot is a slice of
/// the years he has left to the horizon; the ones the phone takes light up
/// vermilion, row by row, under his eyes.
///
/// Nothing on this screen claims a study. The number AND the grid are his two
/// answers, multiplied (ShockMath) — the lit fraction is `years / spanYears`,
/// the same division drawn instead of spoken. That's why it survives a
/// fact-check.
struct ShockStatScreen: View {
    let shock: ShockMath.Result
    let onAdvance: () -> Void

    @State private var counted: Double = 0
    @State private var revealed = false
    /// Dots lit so far — the burn drives it row by row after the count-up.
    @State private var litCount = 0
    @State private var burnStarted = false

    private enum Grid {
        static let columns = 52
        static let rows = 7
        static var totalDots: Int { columns * rows }
        static let dotSize: CGFloat = 4.5
        /// The whole burn, first lit dot to last — fast, relentless.
        static let burnDuration: TimeInterval = 1.2
        /// Unlit dots are cream but quiet — 364 full-brightness dots would
        /// shout over the number.
        static let dormantOpacity: Double = 0.32
    }

    /// Legend and pivot land after the burn finishes, one beat apart.
    private static var legendDelay: TimeInterval {
        OnboardingMetrics.countUpDuration + Grid.burnDuration
    }
    private static var pivotDelay: TimeInterval { legendDelay + 0.55 }

    var body: some View {
        // The block CENTERS between the chrome and the CTA (layout fix
        // 2026-07-16): a drama screen doesn't stack from the top-left corner.
        OnboardingScaffold(step: .shockStat, canAdvance: true,
                           centersVertically: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                // 1 — the setup, secondary at 45 %: it points, it doesn't punch.
                Text(OnboardingCopy.shockLead(shock: shock))
                    .fudoFont(.body(18, weight: .medium))
                    .foregroundStyle(FudoColor.textPrimary)
                    .opacity(0.45)

                // 2 — the blow.
                number
                    .padding(.top, 12)

                // 3 — the grid: his remaining years as dots, the phone's share
                //     burning vermilion through them.
                lifeGrid
                    .padding(.top, 24)

                // 4 — one line under the burn. The grid did the arguing.
                Text("That's your phone.")
                    .fudoFont(.title(20, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 16)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.legendDelay), value: revealed)

                // 5 — the pivot, small, one beat after the legend.
                Text(OnboardingCopy.shockPivot)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 24)
                    .opacity(revealed ? 1 : 0)
                    .animation(AppAnimation.standard.delay(Self.pivotDelay), value: revealed)
            }
        }
        .onboardingWarmWash()
        .task { await runSequence() }
    }

    /// The count-up re-formats through ShockMath's own rule — "1.9 YEARS" or
    /// "205 DAYS", never two spellings of one number. Bebas display, vermillon,
    /// sized to FILL the width like a welcome hook (88 pt base, internal scale
    /// down to fit): the one strong element of the screen.
    private var number: some View {
        CountUpText(value: counted) { ShockMath.headline(for: max(0, $0)).uppercased() }
            .fudoFont(.onboardingDisplay(88))
            .foregroundStyle(FudoColor.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    // MARK: - Life grid

    /// How many of the 364 dots the phone takes: the shock fraction, drawn.
    /// Capped by construction (max 7 h / 24 ≈ 29 %) — the grid never fills.
    private var burnedDots: Int {
        guard shock.spanYears > 0 else { return 0 }
        let fraction = min(max(shock.years / shock.spanYears, 0), 1)
        return Int((fraction * Double(Grid.totalDots)).rounded())
    }

    /// 52 × 7 dots, edge to edge. Row-major: the burn reads like text —
    /// left to right, line by line.
    private var lifeGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<Grid.rows, id: \.self) { row in
                gridRow(row)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(revealed ? 1 : 0)
        .animation(AppAnimation.standard.delay(0.2), value: revealed)
    }

    private func gridRow(_ row: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Grid.columns, id: \.self) { column in
                let index = row * Grid.columns + column
                Circle()
                    .fill(index < litCount ? FudoColor.accent
                                           : FudoColor.textPrimary.opacity(Grid.dormantOpacity))
                    .frame(width: Grid.dotSize, height: Grid.dotSize)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Sequence

    /// Count-up lands (medium hit) → the burn sweeps the grid row by row,
    /// a light tick per row, medium when the last dot lights. Exactly-once:
    /// a backgrounded screen replays its `.task`, `burnStarted` holds the line.
    private func runSequence() async {
        revealed = true
        withAnimation(.easeOut(duration: OnboardingMetrics.countUpDuration)) {
            counted = shock.years
        }
        try? await Task.sleep(for: .seconds(OnboardingMetrics.countUpDuration))
        guard !Task.isCancelled else { return }
        Haptics.medium()   // the blow lands WITH the number, not before it

        guard !burnStarted else { return }
        burnStarted = true
        await runBurn()
    }

    private func runBurn() async {
        let target = burnedDots
        guard target > 0 else { return }
        let rowsToBurn = Int((Double(target) / Double(Grid.columns)).rounded(.up))
        let rowBeat = Grid.burnDuration / Double(rowsToBurn)

        for row in 1...rowsToBurn {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: rowBeat)) {
                litCount = min(row * Grid.columns, target)
            }
            Haptics.light()
            try? await Task.sleep(for: .seconds(rowBeat))
        }
        guard !Task.isCancelled else { return }
        Haptics.medium()   // the last dot — the share is taken
    }
}

#if DEBUG
/// Three profiles, three numbers, three burns — this screen only exists if it
/// says something different to different men.
private struct ShockPreviewHost: View {
    let draft: OnboardingDraft

    var body: some View {
        OnboardingPreviewChrome {
            if let age = draft.age, let scroll = draft.scrollTime {
                ShockStatScreen(shock: ShockMath.result(age: age, scroll: scroll),
                                onAdvance: {})
            }
        }
    }
}

/// 18-24, 4-6 h → "1.9 years", ~21 % of the grid burns (a row and a half).
#Preview("OB 06 — 1.9 years") {
    ShockPreviewHost(draft: .previewAnswered)
}

/// 13-17, 6 h+ → "4.4 years", the heaviest burn the funnel draws (~29 %).
#Preview("OB 06 — 4.4 years (heavy)") {
    ShockPreviewHost(draft: .previewHeavy)
}

/// Under 2 h → "205 days", a thin sliver of one row — the unit swap AND the
/// honest small burn.
#Preview("OB 06 — 205 days (light)") {
    ShockPreviewHost(draft: .previewLight)
}
#endif
