import Charts
import SwiftUI

/// The climb, day by day, straight from the engine. DATA-MODEL §3b is explicit:
/// the onboarding projection MUST call `OVREngine.project(from:days:)` — never a
/// hand-drawn curve. Nothing here decides anything; it plots what the engine
/// already knows.
///
/// NOT `OVRCurveView`: that one is history — green/red segments, real deltas, a
/// tappable popover. This is a promise. All vermillon (a projection has no missed
/// day), nothing to explore. Two meanings, two components.
struct ProjectionCurveView: View {
    let base: Double
    let days: Int
    let rankName: String
    /// 0…days — how much of the climb is drawn. Animated by the screen.
    var drawnDays: Int

    private static let cardHeight: CGFloat = 180
    private static let lineWidth: CGFloat = 3

    private struct Point: Identifiable {
        let id: Int
        let day: Int
        let ovr: Double
    }

    private var points: [Point] {
        (0...days).map { Point(id: $0, day: $0, ovr: OVREngine.project(from: base, days: $0)) }
    }

    private var drawn: [Point] { Array(points.prefix(max(1, drawnDays + 1))) }
    private var isComplete: Bool { drawnDays >= days }
    private var endOVR: Double { points.last?.ovr ?? base }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            chart
            if isComplete {
                Text("~\(OVREngine.displayedOVR(endOVR)) · \(rankName.uppercased())")
                    .fudoFont(.stat(13))
                    .foregroundStyle(FudoColor.accent)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text("\(OVREngine.displayedOVR(base)) · today")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
        }
        .padding(FudoSpacing.cardPadding)
        .frame(height: Self.cardHeight)
        .background { shape.fill(FudoColor.bgCard) }
        .overlay { shape.strokeBorder(FudoColor.border, lineWidth: 1) }
    }

    private var chart: some View {
        Chart {
            ForEach(drawn) { point in
                LineMark(x: .value("Day", point.day), y: .value("OVR", point.ovr))
                    .foregroundStyle(FudoColor.accent)
                    .lineStyle(StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .interpolationMethod(.monotone)
            }

            PointMark(x: .value("Day", 0), y: .value("OVR", base))
                .symbolSize(60)
                .foregroundStyle(FudoColor.textSecondary)

            if isComplete {
                PointMark(x: .value("Day", days), y: .value("OVR", endOVR))
                    .symbolSize(110)
                    .foregroundStyle(FudoColor.accent)
            }
        }
        // The domain is fixed so the line GROWS across the card instead of the
        // card re-scaling under it — the climb reads as a climb.
        .chartXScale(domain: 0...days)
        .chartYScale(domain: (base - 4)...(endOVR + 4))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}
