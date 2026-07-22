import SwiftUI

/// The REPORT, masterclass cut (S5d) — every section is a mini data-viz where
/// he SITUATES himself at a glance. Colour grammar (never inverted): red = him
/// today, grey = the average guy, green = the protocol's target, vermilion =
/// the product speaking. The verdict tag (10 pt caps) carries the instant read;
/// the visual carries the argument; the copy only backs it up (2 lines max).
///
/// Collapsed row: badge + label + hero value + verdict tag, compact viz on the
/// right. Open row (ONE at a time, auto-collapse — spring): the line sits NEXT
/// TO the enlarged viz, never stacked into a slab. Sections cascade in with a
/// 70 ms stagger, each viz animates on appearance. The sections live in a
/// ScrollView: an open fold PUSHES the content down (device bug, batch #3).
/// Every benchmark comes from `ReportBenchmarks` (honesty guard); the OVR is
/// deliberately NOT here — the CTA walks into the reveal.
struct ReportScreen: View {
    let rows: [OnboardingCopy.ReportRow]
    let onAdvance: () -> Void

    private let sections: [ReportSection]
    @State private var expandedID: String?
    @State private var revealed = false

    init(rows: [OnboardingCopy.ReportRow], onAdvance: @escaping () -> Void) {
        self.rows = rows
        self.onAdvance = onAdvance
        let sections = ReportSection.sections(from: rows)
        self.sections = sections
        _expandedID = State(initialValue: sections.first?.id)
    }

    private static let thumbnailWidth: CGFloat = 104
    private static let expandedVizWidth: CGFloat = 132
    private static let cascadeStep: Double = 0.07

    var body: some View {
        // "See what you can become" bridges into the OVR reveal ("Continue" =
        // the fallback variant — Romain arbitrates on device).
        OnboardingScaffold(step: .report, ctaTitle: "See what you can become",
                           canAdvance: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR REPORT")
                    .fudoFont(.onboardingDisplay(44))
                    .foregroundStyle(FudoColor.textPrimary)

                // Scrollable on purpose: 7 sections + an open fold exceed one
                // screen — expansion pushes, the finger follows.
                ScrollView(showsIndicators: false) {
                    reportCard
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            guard !revealed else { return }
            revealed = true
            Haptics.light()
        }
    }

    /// One bordered card, one section per finding — a document, not a feed.
    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                VStack(alignment: .leading, spacing: 0) {
                    if index > 0 {
                        Rectangle()
                            .fill(FudoColor.border)
                            .frame(height: 1)
                    }
                    sectionRow(section)
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 14)
                .animation(.easeOut(duration: 0.5).delay(Double(index) * Self.cascadeStep),
                           value: revealed)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
        .animation(AppAnimation.spring, value: expandedID)
    }

    // MARK: - Section row

    private func sectionRow(_ section: ReportSection) -> some View {
        let expanded = expandedID == section.id
        return Button {
            Haptics.light()
            expandedID = expanded ? nil : section.id
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                collapsedHeader(section, expanded: expanded)
                if expanded {
                    unfoldedBody(section)
                        .padding(.top, 12)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            // The row grows when open — the open fold breathes, the closed stay tight.
            .padding(.vertical, expanded ? 16 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Badge + label + hero value + verdict tag; the compact viz thumbnail on
    /// the right (hidden while open — the big cut replaces it, no duplicate).
    private func collapsedHeader(_ section: ReportSection, expanded: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: section.icon)
                .fudoFont(.glyph(15))
                .foregroundStyle(FudoColor.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(section.label)
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Text(section.value)
                    .fudoFont(.title(18, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                verdictTag(section.verdict)
            }

            Spacer(minLength: 8)

            if !expanded, let viz = section.viz {
                vizView(viz, compact: true)
                    .frame(width: Self.thumbnailWidth)
            }

            Image(systemName: "chevron.down")
                .fudoFont(.glyph(11, weight: .semibold))
                .foregroundStyle(FudoColor.textSecondary)
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
    }

    /// Open fold: the line NEXT TO the enlarged viz — text ~60 %, graph ~40 %.
    /// Sections without a viz hand the line the full width.
    @ViewBuilder private func unfoldedBody(_ section: ReportSection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if let detail = section.detail {
                Text(detail)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let viz = section.viz {
                vizView(viz, compact: false)
                    .frame(width: Self.expandedVizWidth)
            }
        }
        .padding(.leading, 34)   // aligns under the value, clear of the badge column
    }

    // MARK: - Verdict tag

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

    // MARK: - Viz dispatch

    /// GeometryReader-based vizzes (dial rail, curve) get explicit heights;
    /// the others size intrinsically.
    @ViewBuilder private func vizView(_ viz: ReportSection.Viz, compact: Bool) -> some View {
        switch viz {
        case let .bars(gauge):
            ReportGaugeView(gauge: gauge, compact: compact)
        case let .dial(gauge):
            ReportDialView(gauge: gauge, compact: compact)
        case let .weekDots(filled, target):
            ReportDotsView(mode: .week(filled: filled, target: target), compact: compact)
        case .streakDots:
            ReportDotsView(mode: .streak, compact: compact)
        case .curve:
            ReportCurveView(compact: compact)
                .frame(width: compact ? 100 : Self.expandedVizWidth,
                       height: compact ? 36 : 64)
        }
    }
}

#if DEBUG
#Preview("Report S5d — full draft (first open)") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewAnswered), onAdvance: {})
    }
}

/// The heaviest profile — longest lines, worst gauges, red tags everywhere.
/// Open every section one by one in the live canvas: single-open must hold.
#Preview("Report S5d — heavy profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewHeavy), onAdvance: {})
    }
}

/// The disciplined case — YOU legitimately beats AVERAGE: green tags up,
/// honest bars, no flattery.
#Preview("Report S5d — light profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewLight), onAdvance: {})
    }
}
#endif
