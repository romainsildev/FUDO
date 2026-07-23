import SwiftUI

/// The REPORT, gamified cut (design pass 2026-07-23 — Romain: soft, round,
/// finished, low mental load; the clinical document is gone). Three storeys:
///
///  1. HERO — the sensei hands him the report: the master centered in a
///     vermilion ring that draws itself in, warm aura behind, then two lines —
///     his stated fight and the honest verdict count.
///  2. GRID — 2×2 soft glass cards, one per benchmarked domain. Each card:
///     label, his own answer as the hero figure (the proof of computation),
///     one rail (red dot = him, grey tick = average, green tick = target),
///     and a ▲/▼ corner badge. One shape per card, nothing else to read.
///  3. CLOSING — potential curve + his track record's pivot line, then the
///     CTA. The CTA exists nowhere else: reaching it means the report was read.
///
/// Colour grammar (never inverted): red = him today, grey = the average guy,
/// green = the protocol's target, vermilion = the product speaking. Every
/// benchmark comes from `ReportBenchmarks` (honesty guard); the OVR is
/// deliberately NOT here — the reveal is the next screen.
struct ReportScreen: View {
    let rows: [OnboardingCopy.ReportRow]
    let onAdvance: () -> Void

    private let summary: ReportSummary

    init(rows: [OnboardingCopy.ReportRow], onAdvance: @escaping () -> Void) {
        self.rows = rows
        self.onAdvance = onAdvance
        self.summary = ReportSummary.summary(from: rows)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — the bar renders at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                // Lazy on purpose: a block's onAppear IS its scroll-in trigger.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ReportHeroBlock(summary: summary, answerCount: rows.count)
                        .padding(.top, 12)

                    if !summary.cards.isEmpty {
                        ReportCardGrid(cards: summary.cards)
                            .padding(.top, 28)
                    }

                    ReportClosingBlock(summary: summary, onAdvance: onAdvance)
                        .padding(.top, 36)
                        .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
    }
}

// MARK: - Metrics

private enum ReportMetrics {
    static let ringDiameter: CGFloat = 190
    static let senseiHeight: CGFloat = 176
    static let ringDraw: TimeInterval = 0.6
    /// Cascade step between the grid's cards.
    static let cardStagger: TimeInterval = 0.07
    static let gridSpacing: CGFloat = 12
}

// MARK: - Hero

/// Title, then the sensei in his ring, then the two lines. One entrance
/// choreography: ring draws in → light haptic → lines rise, staggered.
private struct ReportHeroBlock: View {
    let summary: ReportSummary
    let answerCount: Int

    @State private var ringProgress: CGFloat = 0
    @State private var senseiVisible = false
    @State private var linesVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR REPORT")
                .fudoFont(.onboardingDisplay(44))
                .foregroundStyle(FudoColor.textPrimary)

            Text("Computed from your \(answerCount) answers. Nothing invented.")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            stage
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            heroLines
                .padding(.top, 18)
        }
        .task { await run() }
    }

    /// Sensei centered in the day-ring recipe (aura + track + vermilion arc) —
    /// the Home stage's grammar, sized for a document header.
    private var stage: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accent.opacity(senseiVisible ? 0.14 : 0), .clear],
                           center: .center, startRadius: 16,
                           endRadius: ReportMetrics.ringDiameter * 0.65)
                .animation(AppAnimation.slow, value: senseiVisible)

            Circle()
                .stroke(FudoColor.border, lineWidth: FudoSpacing.ringWidth)
                .frame(width: ReportMetrics.ringDiameter, height: ReportMetrics.ringDiameter)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(FudoColor.accent,
                        style: StrokeStyle(lineWidth: FudoSpacing.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ReportMetrics.ringDiameter, height: ReportMetrics.ringDiameter)

            SenseiAssetProvider.image(for: .sensei)
                .resizable()
                .scaledToFit()
                .frame(height: ReportMetrics.senseiHeight)
                .opacity(senseiVisible ? 1 : 0)
                .scaleEffect(senseiVisible ? 1 : 0.94)
                .animation(AppAnimation.slow, value: senseiVisible)
        }
        .frame(height: ReportMetrics.ringDiameter + 8)
    }

    private var heroLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fight = summary.fight {
                (Text("Your fight: ").foregroundStyle(FudoColor.textSecondary)
                    + Text(fight).foregroundStyle(FudoColor.textPrimary))
                    .fudoFont(.body(15, weight: .semibold))
            }

            Text(summary.verdictLine)
                .fudoFont(.title(20, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(linesVisible ? 1 : 0)
        .offset(y: linesVisible ? 0 : 12)
    }

    private func run() async {
        senseiVisible = true
        withAnimation(.easeOut(duration: ReportMetrics.ringDraw)) { ringProgress = 1 }
        try? await Task.sleep(for: .seconds(ReportMetrics.ringDraw))
        guard !Task.isCancelled else { return }
        Haptics.light()
        withAnimation(AppAnimation.standard) { linesVisible = true }
    }
}

// MARK: - Card grid

/// 2×2 soft cards, cascading in on scroll-entry.
private struct ReportCardGrid: View {
    let cards: [ReportSummary.Card]

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: ReportMetrics.gridSpacing),
        GridItem(.flexible(), spacing: ReportMetrics.gridSpacing),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: ReportMetrics.gridSpacing) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                ReportDomainCard(card: card)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(AppAnimation.standard
                        .delay(Double(index) * ReportMetrics.cardStagger),
                               value: appeared)
            }
        }
        .onAppear { appeared = true }
    }
}

/// One domain: label, his value, the rail, a corner verdict badge. His value
/// IS the restated answer — the proof the rail was computed from him.
private struct ReportDomainCard: View {
    let card: ReportSummary.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: card.icon)
                    .fudoFont(.glyph(11))
                    .foregroundStyle(FudoColor.accent)
                Text(card.label)
                    .fudoFont(.label(9, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(FudoColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(card.value)
                .fudoFont(.stat(19))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.top, 10)

            ReportDialView(gauge: card.gauge)
                .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FudoGlassCard() }
        .overlay(alignment: .topTrailing) { badge.padding(9) }
    }

    /// ▲/▼, instant read — the arrow carries the green/red (palette rule).
    private var badge: some View {
        let color = card.beatsAverage ? FudoColor.positive : FudoColor.negative
        return Image(systemName: card.beatsAverage ? "arrow.up" : "arrow.down")
            .fudoFont(.glyph(8, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background { Circle().fill(color.opacity(0.14)) }
    }
}

// MARK: - Closing + CTA

/// The ramp to the reveal: the potential curve rising off the average's flat
/// line, his own numbers as the promise, his own history as the pivot — then
/// the CTA slides in. Nothing here is a new claim.
private struct ReportClosingBlock: View {
    let summary: ReportSummary
    let onAdvance: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("POTENTIAL")
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            ReportCurveView()
                .frame(height: 64)
                .padding(.top, 14)

            if let potential = summary.potentialLine {
                Text("\(potential).")
                    .fudoFont(.title(20, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }

            if let trackRecord = summary.trackRecordLine {
                Text(trackRecord)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            Button(action: onAdvance) {
                Text("See what you can become")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(FudoColor.accent) }
            }
            .buttonStyle(.plain)
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(AppAnimation.standard) { appeared = true }
        }
    }
}

#if DEBUG
#Preview("Report — full draft") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewAnswered), onAdvance: {})
    }
}

/// The heaviest profile — every badge down, the verdict at its bluntest.
/// Scroll to the very end in the canvas: the CTA must not exist before the
/// closing block.
#Preview("Report — heavy profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewHeavy), onAdvance: {})
    }
}

/// The disciplined case — YOU legitimately beats AVERAGE: badges up, the
/// flattering verdict he actually earned.
#Preview("Report — light profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewLight), onAdvance: {})
    }
}
#endif
