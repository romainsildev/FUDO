import SwiftUI

/// The report's bar viz (S5d masterclass cut): three horizontal bars — YOU vs
/// AVERAGE vs TARGET — that FILL on appearance (ease-out, premium tempo). Red =
/// his level, grey = the public rounded average, green = the protocol's bar
/// (validation exception to the no-green rule, acted). No axis, no percentile:
/// the relative position IS the message (honesty guard).
///
/// `compact` is the collapsed row's thumbnail: bars only, no labels — the
/// expanded cut adds label + value per bar.
struct ReportGaugeView: View {
    let gauge: ReportGauge
    var compact: Bool = false

    /// 0 → 1 on appearance; every bar reads its fraction through it, so the
    /// three fill together on one curve.
    @State private var fill: CGFloat = 0

    private var barHeight: CGFloat { compact ? 4 : 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 9) {
            markBlock(gauge.you, color: FudoColor.negative)
            markBlock(gauge.average, color: FudoColor.textSecondary)
            markBlock(gauge.target, color: FudoColor.positive)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { fill = 1 }
        }
    }

    private func markBlock(_ mark: ReportGauge.Mark, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !compact {
                HStack(spacing: 6) {
                    Text(mark.label)
                        .fudoFont(.label(9, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(FudoColor.textSecondary)
                    Spacer(minLength: 4)
                    Text(mark.valueLabel)
                        .fudoFont(.caption(10, weight: .semibold))
                        .foregroundStyle(FudoColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FudoColor.border.opacity(0.6))
                    Capsule()
                        .fill(color)
                        .frame(width: max(barHeight,
                                          geometry.size.width * mark.fraction * fill))
                }
            }
            .frame(height: barHeight)
        }
    }
}

#if DEBUG
#Preview("Bars — screen time (heavy), expanded") {
    ZStack {
        FudoColor.bgCard
        ReportGaugeView(gauge: ReportBenchmarks.screenGauge(scroll: .sixHoursPlus))
            .frame(width: 132)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Bars — focus, compact thumbnail") {
    ZStack {
        FudoColor.bgCard
        ReportGaugeView(gauge: ReportBenchmarks.focusGauge(span: .underTen), compact: true)
            .frame(width: 112)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
