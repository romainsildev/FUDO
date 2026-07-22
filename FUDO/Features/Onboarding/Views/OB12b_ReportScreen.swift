import SwiftUI

/// The REPORT, document cut (design pass 2026-07-22 — Whoop hero figures, Noom
/// restated answers, Typeform skeleton). The accordion and its single card are
/// GONE: this is one continuous scrollable document — header, then full-width
/// sections stacked, then a closing verdict, then the CTA. The CTA does not
/// exist on screen until he has scrolled to the end: the report must be READ,
/// not skipped.
///
/// Each section: eyebrow → his own answer restated ("You said: …", the proof
/// of computation) → a HERO figure (counts up as it scrolls in) → the viz at
/// full section width → verdict tag → one line of prescription. Sections
/// reveal on scroll-in (LazyVStack: `onAppear` fires at viewport entry), never
/// in one global pass.
///
/// Colour grammar (never inverted): red = him today, grey = the average guy,
/// green = the protocol's target, vermilion = the product speaking. Every
/// benchmark comes from `ReportBenchmarks` (honesty guard); the OVR is
/// deliberately NOT here — the CTA walks into the reveal.
struct ReportScreen: View {
    let rows: [OnboardingCopy.ReportRow]
    let onAdvance: () -> Void

    private let sections: [ReportSection]

    init(rows: [OnboardingCopy.ReportRow], onAdvance: @escaping () -> Void) {
        self.rows = rows
        self.onAdvance = onAdvance
        self.sections = ReportSection.sections(from: rows)
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
                    header
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    ForEach(sections) { section in
                        sectionDivider
                        ReportSectionBlock(section: section,
                                           saidLine: saidLine(for: section))
                    }

                    sectionDivider
                    ReportClosingBlock(sections: sections, onAdvance: onAdvance)
                        .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
    }

    // MARK: - Header (scrolls away with the content — no space wasted up top)

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR REPORT")
                .fudoFont(.onboardingDisplay(44))
                .foregroundStyle(FudoColor.textPrimary)

            // Honest methodology, one line: his answers, today's date, nothing else.
            Text("\(OnboardingCopy.longDate(.now)) · Computed from your \(rows.count) answers. Nothing invented.")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(FudoColor.border)
            .frame(height: 1)
    }

    /// "You said: …" — the Noom move: restate the answer the numbers were
    /// computed from. Only on benchmarked sections, and only when the hero
    /// figure isn't already the same words (a hero repeating its own proof line
    /// reads as padding, not proof).
    private func saidLine(for section: ReportSection) -> String? {
        guard section.heroIsDerived else { return nil }
        return "You said: \(section.value.lowercased())"
    }
}

// MARK: - Section block

/// One full-width section of the document. Owns its scroll-in state: reveal
/// (opacity + rise) fires on `onAppear` — inside a LazyVStack that means
/// viewport entry, and the viz components animate on their own appearance.
private struct ReportSectionBlock: View {
    let section: ReportSection
    let saidLine: String?

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow — badge + tracked label.
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .fudoFont(.glyph(13))
                    .foregroundStyle(FudoColor.accent)
                Text(section.label)
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
            }

            if let saidLine {
                Text(saidLine)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 10)
            }

            // The hero figure — the section's one big number (or word).
            ReportHeroText(value: section.heroValue, play: appeared)
                .padding(.top, saidLine == nil ? 12 : 6)

            verdictTag(section.verdict)
                .padding(.top, 10)

            if let viz = section.viz {
                vizView(viz)
                    .padding(.top, 16)
            }

            if let detail = section.detail {
                Text(detail)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    private func verdictTag(_ verdict: ReportSection.Verdict) -> some View {
        let color = toneColor(verdict.tone)
        return HStack(spacing: 4) {
            if let beats = verdict.beatsAverage {
                Image(systemName: beats ? "arrow.up" : "arrow.down")
                    .fudoFont(.glyph(8, weight: .bold))
            }
            Text(verdict.text)
                .fudoFont(.label(10, weight: .bold))
                .kerning(1.2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(color.opacity(0.12))
        }
    }

    private func toneColor(_ tone: ReportSection.Tone) -> Color {
        switch tone {
        case .good: return FudoColor.positive
        case .bad: return FudoColor.negative
        case .accent: return FudoColor.accent
        case .neutral: return FudoColor.textSecondary
        }
    }

    /// Full section width for every viz — the 104 pt thumbnail era is over.
    /// GeometryReader-based ones (dial rail, curve) get explicit heights.
    @ViewBuilder private func vizView(_ viz: ReportSection.Viz) -> some View {
        switch viz {
        case let .bars(gauge):
            ReportGaugeView(gauge: gauge)
        case let .dial(gauge):
            ReportDialView(gauge: gauge)
        case let .weekDots(filled, target):
            ReportDotsView(mode: .week(filled: filled, target: target))
        case .streakDots:
            ReportDotsView(mode: .streak)
        case .curve:
            ReportCurveView()
                .frame(height: 72)
        }
    }
}

// MARK: - Hero figure

/// The section's big number. When the value opens on digits it COUNTS UP on
/// scroll-in (monospaced stat face, the suffix preserved through the format
/// closure — one spelling in flight and at rest); a word hero just lands with
/// the block's reveal.
private struct ReportHeroText: View {
    let value: String
    let play: Bool

    @State private var counted: Double = 0

    /// Leading number split: prefix symbols (~, ≈), the numeric part, the rest.
    private var numeric: (target: Double, decimals: Bool, prefix: String, suffix: String)? {
        var prefix = ""
        var rest = Substring(value)
        while let first = rest.first, "~≈".contains(first) {
            prefix.append(first)
            rest = rest.dropFirst()
        }
        let digits = rest.prefix { $0.isNumber || $0 == "." }
        guard let target = Double(digits), !digits.isEmpty else { return nil }
        return (target, digits.contains("."), prefix, String(rest.dropFirst(digits.count)))
    }

    var body: some View {
        if let numeric {
            CountUpText(value: counted) { current in
                let clamped = max(0, current)
                let figure = numeric.decimals
                    ? "\((clamped * 10).rounded() / 10)"
                    : "\(Int(clamped.rounded()))"
                return numeric.prefix + figure + numeric.suffix
            }
            .fudoFont(.stat(44))
            .foregroundStyle(FudoColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .onChange(of: play, initial: true) { _, playing in
                guard playing else { return }
                withAnimation(.easeOut(duration: 0.8)) { counted = numeric.target }
            }
        } else {
            Text(value)
                .fudoFont(.title(34, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Closing verdict + CTA

/// The end of the document: one synthesis line computed from his own verdict
/// tags (nothing new is claimed), then the CTA slides in — it exists nowhere
/// else on the screen, so reaching it means the report was read.
private struct ReportClosingBlock: View {
    let sections: [ReportSection]
    let onAdvance: () -> Void

    @State private var appeared = false

    private var benchmarked: [ReportSection] {
        sections.filter { $0.verdict.beatsAverage != nil }
    }
    private var deficits: Int {
        benchmarked.filter { $0.verdict.beatsAverage == false }.count
    }

    private var verdictLine: String {
        if benchmarked.isEmpty {
            return "The protocol turns what you told us into a daily score."
        }
        if deficits == 0 {
            return "Above the average man on every benchmark. The protocol turns that into rank."
        }
        let plural = deficits == 1 ? "benchmark" : "benchmarks"
        return "\(deficits) of \(benchmarked.count) \(plural) below the average man. The protocol attacks every one from day 1."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THE VERDICT")
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            Text(verdictLine)
                .fudoFont(.title(22, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Button(action: onAdvance) {
                Text("See what you can become")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(FudoColor.accent) }
            }
            .buttonStyle(.plain)
            .padding(.top, 28)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

// MARK: - Hero derivation

extension ReportSection {
    /// Benchmarked sections carry a derived hero (the gauge's own YOU value —
    /// "5 h", "8 min"); qualitative ones ARE their own hero (the answer).
    var heroIsDerived: Bool {
        if let viz {
            switch viz {
            case .bars, .dial: return true
            // TRAINING's hero stays his answer (the dots carry the numbers) —
            // a derived hero here would just repeat the said line.
            case .weekDots, .streakDots, .curve: return false
            }
        }
        return false
    }

    /// What the big figure prints: the gauge's YOU value where one exists
    /// (the number his bars are drawn from — one source), else the answer.
    var heroValue: String {
        guard heroIsDerived, let viz else { return value }
        switch viz {
        case let .bars(gauge), let .dial(gauge):
            return gauge.you.valueLabel
        case .weekDots:
            return value
        case .streakDots, .curve:
            return value
        }
    }
}

#if DEBUG
#Preview("Report document — full draft") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewAnswered), onAdvance: {})
    }
}

/// The heaviest profile — longest lines, worst gauges, red tags everywhere,
/// the closing verdict at its bluntest. Scroll to the very end in the canvas:
/// the CTA must not exist before the last section.
#Preview("Report document — heavy profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewHeavy), onAdvance: {})
    }
}

/// The disciplined case — YOU legitimately beats AVERAGE: green tags up,
/// honest bars, the flattering verdict he actually earned.
#Preview("Report document — light profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewLight), onAdvance: {})
    }
}
#endif
