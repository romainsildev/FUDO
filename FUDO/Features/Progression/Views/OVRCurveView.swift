import SwiftUI
import Charts

/// Sober OVR sparkline: the day-by-day history of the run, rising segments in green, falling
/// segments in red, points tappable for a per-day popover (date · delta · complete/incomplete).
/// Below two points there is no curve to draw, so the card shows a calm caption instead of an
/// empty chart.
struct OVRCurveView: View {
    let points: [CurvePoint]
    let windowLabel: String
    let weekNet: Int?

    @State private var selectedDate: Date?

    private var selectedPoint: CurvePoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// Consecutive pairs — each drawn as its own two-point line so it can carry its own colour.
    private var segments: [CurveSegment] {
        guard points.count >= 2 else { return [] }
        return (1..<points.count).map { CurveSegment(id: $0, from: points[$0 - 1], to: points[$0]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if points.count >= 2 {
                chart
            } else {
                caption
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text(windowLabel.uppercased())
                .font(FudoFont.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            if let weekNet, weekNet != 0 {
                let up = weekNet > 0
                Label("\(up ? "+" : "")\(weekNet) this week", systemImage: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(FudoFont.caption(13).weight(.semibold))
                    .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var caption: some View {
        Text("Your OVR curve fills in as the challenge goes. Come back tomorrow.")
            .font(FudoFont.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            ForEach(segments) { segment in
                let colour = segment.rising ? FudoColor.positive : FudoColor.negative
                LineMark(x: .value("Day", segment.from.date), y: .value("OVR", segment.from.value),
                         series: .value("Segment", segment.id))
                    .foregroundStyle(colour)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", segment.to.date), y: .value("OVR", segment.to.value),
                         series: .value("Segment", segment.id))
                    .foregroundStyle(colour)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }

            ForEach(points) { point in
                PointMark(x: .value("Day", point.date), y: .value("OVR", point.value))
                    .symbolSize(selectedPoint?.id == point.id ? 90 : 26)
                    .foregroundStyle(FudoColor.textPrimary)
            }

            if let selectedPoint {
                RuleMark(x: .value("Day", selectedPoint.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(FudoColor.border)
                    .annotation(position: .top,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        PointPopover(point: selectedPoint)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .frame(height: 120)
        .padding(.top, selectedPoint == nil ? 0 : 44)   // headroom for the popover annotation
        .animation(AppAnimation.standard, value: selectedPoint)
    }
}

/// A rising / falling segment of the curve.
private struct CurveSegment: Identifiable {
    let id: Int
    let from: CurvePoint
    let to: CurvePoint
    var rising: Bool { to.value >= from.value }
}

/// The tap popover for a single day: date, OVR delta (coloured arrow), and — when the day
/// closed as a challenge day — whether it was complete.
private struct PointPopover: View {
    let point: CurvePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProgressionViewModel.shortDate(point.date))
                .font(FudoFont.caption(13).weight(.semibold))
                .foregroundStyle(FudoColor.textPrimary)
            deltaLine
            if let complete = point.isComplete {
                Text(complete ? "Complete" : "Incomplete")
                    .font(FudoFont.caption(12))
                    .foregroundStyle(complete ? FudoColor.positive : FudoColor.negative)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                .fill(FudoColor.bgPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder private var deltaLine: some View {
        let rounded = Int(point.delta.rounded())
        if rounded == 0 {
            Text("OVR \(OVREngine.displayedOVR(point.value))")
                .font(FudoFont.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
        } else {
            let up = rounded > 0
            Label("\(up ? "+" : "")\(rounded) OVR", systemImage: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(FudoFont.caption(12).weight(.semibold))
                .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
                .labelStyle(.titleAndIcon)
        }
    }
}
