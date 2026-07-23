import SwiftUI

/// THE card rail (gamified cut 2026-07-23): one soft rounded track, three
/// marks — his position as a red dot, the average as a grey tick, the target
/// as a green tick. The dot slides from the target out to his real position on
/// appearance: the gap between green and red IS the message.
///
/// The graph labels itself (airy pass, same day): each tick's value sits right
/// under it — "~4h30" grey, "2 h" green. No caption sentence; his own value is
/// the card's hero figure, never repeated here.
///
/// Display note: the three marks are re-spread across the rail (min → 0.08,
/// max → 0.92) so clustered values stay readable — the ORDER and the printed
/// values are the honest part, the rail has no axis to lie about.
struct ReportDialView: View {
    let gauge: ReportGauge

    @State private var slide: CGFloat = 0

    private static let railHeight: CGFloat = 6
    private static let tickSize = CGSize(width: 2, height: 14)
    private static let dotDiameter: CGFloat = 14
    /// Room under the rail for the tick value labels.
    private static let labelBand: CGFloat = 18
    /// Widest a tick label renders before its position gets clamped inboard.
    private static let labelWidth: CGFloat = 52

    var body: some View {
        rail
            .frame(height: max(Self.tickSize.height, Self.dotDiameter) + Self.labelBand)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { slide = 1 }
            }
    }

    private var rail: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let markHeight = max(Self.tickSize.height, Self.dotDiameter)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(FudoColor.border.opacity(0.6))
                    .frame(height: Self.railHeight)
                    .frame(height: markHeight)

                tick(color: FudoColor.textSecondary)
                    .frame(height: markHeight)
                    .offset(x: width * spread(gauge.average.fraction) - Self.tickSize.width / 2)
                tick(color: FudoColor.positive)
                    .frame(height: markHeight)
                    .offset(x: width * spread(gauge.target.fraction) - Self.tickSize.width / 2)

                // His dot starts on the target and slides out to where he is:
                // the travelled distance is the deficit, drawn.
                Circle()
                    .fill(FudoColor.negative)
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                    .frame(height: markHeight)
                    .offset(x: width * youPosition(animated: slide) - Self.dotDiameter / 2)

                // The ticks' values, right under them — the rail's only words.
                tickLabel(gauge.average.valueLabel, color: FudoColor.textSecondary,
                          at: spread(gauge.average.fraction), width: width)
                    .offset(y: markHeight + 4)
                tickLabel(gauge.target.valueLabel, color: FudoColor.positive,
                          at: spread(gauge.target.fraction), width: width)
                    .offset(y: markHeight + 4)
            }
        }
    }

    /// A value centered on its tick, clamped so edge ticks keep their label
    /// inside the rail's bounds.
    private func tickLabel(_ value: String, color: Color,
                           at position: CGFloat, width: CGFloat) -> some View {
        let half = Self.labelWidth / 2
        let center = min(max(width * position, half), width - half)
        return Text(value)
            .fudoFont(.caption(10, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: Self.labelWidth)
            .offset(x: center - half)
    }

    private func tick(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: Self.tickSize.width, height: Self.tickSize.height)
            .frame(maxHeight: .infinity)
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
#Preview("Rail — screen time (heavy)") {
    ZStack {
        FudoColor.bgCard
        ReportDialView(gauge: ReportBenchmarks.screenGauge(scroll: .sixHoursPlus))
            .frame(width: 150)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Rail — up before 6") {
    ZStack {
        FudoColor.bgCard
        ReportDialView(gauge: ReportBenchmarks.wakeGauge(bracket: .beforeSix))
            .frame(width: 320)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
