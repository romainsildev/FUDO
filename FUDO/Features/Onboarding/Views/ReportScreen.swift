import SwiftUI

/// The REPORT — what the analysis loader was "computing" (restructure
/// 2026-07-16, RiteOff pattern). The ONE dense screen the funnel allows: its
/// job is the synthesis — his fight, his hours, his weak spot, his targets,
/// his potential — laid out as a document he paid for with his answers. The
/// OVR is deliberately NOT here: "Continue" walks into the reveal.
struct ReportScreen: View {
    let rows: [OnboardingCopy.ReportRow]
    let onAdvance: () -> Void

    private static let icons: [String: String] = [
        "THE FIGHT": "target",
        "SCREEN TIME": "hourglass",
        "WEAK SPOT": "exclamationmark.triangle",
        "TARGETS": "checkmark.circle",
        "POTENTIAL": "arrow.up.right",
    ]

    var body: some View {
        OnboardingScaffold(step: .report, canAdvance: true, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR REPORT")
                    .fudoFont(.onboardingDisplay(44))
                    .foregroundStyle(FudoColor.textPrimary)

                reportCard
                    .padding(.top, 24)
            }
        }
    }

    /// One bordered card, one row per finding — a document, not a feed.
    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(FudoColor.border)
                        .frame(height: 1)
                }
                rowView(row)
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
    }

    private func rowView(_ row: OnboardingCopy.ReportRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Self.icons[row.label] ?? "circle")
                .fudoFont(.glyph(15))
                .foregroundStyle(FudoColor.accent)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.label)
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Text(row.value)
                    .fudoFont(.body(16, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail {
                    Text(detail)
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.cardPadding)
        .padding(.vertical, 13)
    }
}

#if DEBUG
#Preview("Report — full draft") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewAnswered), onAdvance: {})
    }
}

/// The heaviest profile the funnel can produce — the longest lines must fit.
#Preview("Report — heavy profile") {
    OnboardingPreviewChrome {
        ReportScreen(rows: OnboardingCopy.reportRows(draft: .previewHeavy), onAdvance: {})
    }
}
#endif
