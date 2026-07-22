import SwiftUI

/// The MORNING viz (S5d): a wake-up hour track. One horizontal rail, three
/// markers — his hour as a red dot, the average as a grey tick, the target as
/// a green tick. The dot slides to its position on appearance.
///
/// Display note: the three marks are re-spread across the rail (min → 0.08,
/// max → 0.92) so clustered hours stay readable — the ORDER and the printed
/// values are the honest part, the rail has no axis to lie about.
struct ReportDialView: View {
    let gauge: ReportGauge
    var compact: Bool = false

    @State private var slide: CGFloat = 0

    private static let railHeight: CGFloat = 4
    private static let tickSize = CGSize(width: 2, height: 12)
    private var dotDiameter: CGFloat { compact ? 10 : 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 10) {
            rail
                .frame(height: max(Self.tickSize.height, dotDiameter))

            if !compact {
                legend
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { slide = 1 }
        }
    }

    private var rail: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FudoColor.border.opacity(0.6))
                    .frame(height: Self.railHeight)
                    .frame(maxHeight: .infinity)

                tick(color: FudoColor.textSecondary)
                    .offset(x: width * spread(gauge.average.fraction) - Self.tickSize.width / 2)
                tick(color: FudoColor.positive)
                    .offset(x: width * spread(gauge.target.fraction) - Self.tickSize.width / 2)

                // His dot starts on the target and slides out to his real hour:
                // the gap between green and red IS the message.
                Circle()
                    .fill(FudoColor.negative)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .offset(x: width * youPosition(animated: slide) - dotDiameter / 2)
            }
        }
    }

    private func tick(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: Self.tickSize.width, height: Self.tickSize.height)
            .frame(maxHeight: .infinity)
    }

    /// Vertical rows, same reading order as the bar viz: role left, value
    /// right — the two graphs stay one grammar.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            legendItem(color: FudoColor.negative, mark: gauge.you)
            legendItem(color: FudoColor.textSecondary, mark: gauge.average)
            legendItem(color: FudoColor.positive, mark: gauge.target)
        }
    }

    private func legendItem(color: Color, mark: ReportGauge.Mark) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
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

    // MARK: - Geometry

    /// Linear re-spread of the raw fractions so the three marks use the rail.
    private func spread(_ fraction: Double) -> CGFloat {
        let values = [gauge.you.fraction, gauge.average.fraction, gauge.target.fraction]
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return 0.5 }
        let normalized = (fraction - lo) / (hi - lo)
        return CGFloat(0.08 + normalized * 0.84)
    }

    /// The dot's appearance path: target position → his position.
    private func youPosition(animated progress: CGFloat) -> CGFloat {
        let from = spread(gauge.target.fraction)
        let to = spread(gauge.you.fraction)
        return from + (to - from) * progress
    }
}

#if DEBUG
#Preview("Dial — wakes after 9, expanded") {
    ZStack {
        FudoColor.bgCard
        ReportDialView(gauge: ReportBenchmarks.wakeGauge(bracket: .afterNine))
            .frame(width: 200)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Dial — up before 6, compact") {
    ZStack {
        FudoColor.bgCard
        ReportDialView(gauge: ReportBenchmarks.wakeGauge(bracket: .beforeSix), compact: true)
            .frame(width: 112)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
