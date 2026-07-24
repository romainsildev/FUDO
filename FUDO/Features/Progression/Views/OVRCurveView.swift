import SwiftUI
import Charts

/// The OVR day-by-day graph (Prog FINAL, 2026-07-23): one cream line over the run,
/// gold dashed rules where a rank floor was crossed ("DISCIPLE — DAY 5"), and the
/// current value as a vermillon endpoint. Rising/falling greens and reds are gone —
/// the week delta in the header carries the only green. Points stay tappable for the
/// per-day popover. Below two points the card shows a calm caption instead.
struct OVRCurveView: View {
    let points: [CurvePoint]
    let milestones: [RankMilestone]
    let windowLabel: String
    let weekNet: Int?

    @State private var selectedDate: Date?

    private var selectedPoint: CurvePoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// Y-window: the curve plus every drawn floor, with headroom for the gold labels
    /// above their rules and the endpoint annotation.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value) + milestones.map(\.floor)
        guard let min = values.min(), let max = values.max() else { return 0...100 }
        return (min - 2)...(max + 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if points.count >= 2 {
                chart
                axisFooter
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
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            if let weekNet, weekNet != 0 {
                let up = weekNet > 0
                Label("\(up ? "+" : "")\(weekNet) this week", systemImage: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .fudoFont(.caption(13, weight: .semibold))
                    .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var caption: some View {
        Text("Your OVR curve fills in as the challenge goes. Come back tomorrow.")
            .fudoFont(.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            // Crossed rank floors — gold: the frozen celebration of a threshold taken.
            ForEach(milestones) { milestone in
                RuleMark(y: .value("Floor", milestone.floor))
                    .foregroundStyle(FudoColor.celebrationGold.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .annotation(position: .top, alignment: .leading, spacing: 3,
                                overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
                        Text("\(milestone.name.uppercased()) — DAY \(milestone.dayNumber)")
                            .fudoFont(.label(9, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(FudoColor.celebrationGold)
                    }
            }

            // The run itself — one cream line, no per-segment verdict colours.
            ForEach(points) { point in
                LineMark(x: .value("Day", point.date), y: .value("OVR", point.value))
                    .foregroundStyle(FudoColor.textPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }

            // Where you started…
            if let first = points.first {
                PointMark(x: .value("Day", first.date), y: .value("OVR", first.value))
                    .symbolSize(0)
                    .annotation(position: .bottom, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                        Text("\(OVREngine.displayedOVR(first.value))")
                            .fudoFont(.caption(11, weight: .semibold))
                            .foregroundStyle(FudoColor.textSecondary)
                    }
            }

            // …and where you are: the vermillon endpoint carrying today's number.
            if let last = points.last {
                PointMark(x: .value("Day", last.date), y: .value("OVR", last.value))
                    .symbolSize(70)
                    .foregroundStyle(FudoColor.accent)
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                        Text("\(OVREngine.displayedOVR(last.value))")
                            .fudoFont(.stat(15))
                            .foregroundStyle(FudoColor.textPrimary)
                    }
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
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .frame(height: 150)
        .padding(.top, selectedPoint == nil ? 0 : 44)   // headroom for the popover annotation
        .animation(AppAnimation.standard, value: selectedPoint)
    }

    private var axisFooter: some View {
        HStack {
            Text("DAY 1")
            Spacer()
            Text("DAY \(points.count)")
        }
        .fudoFont(.label(9))
        .kerning(0.8)
        .foregroundStyle(FudoColor.textSecondary.opacity(0.7))
    }
}

/// The tap popover for a single day: date, OVR delta (coloured arrow), and — when the day
/// closed as a challenge day — whether it was complete.
private struct PointPopover: View {
    let point: CurvePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProgressionViewModel.shortDate(point.date))
                .fudoFont(.caption(13, weight: .semibold))
                .foregroundStyle(FudoColor.textPrimary)
            deltaLine
            if let complete = point.isComplete {
                Text(complete ? "Complete" : "Incomplete")
                    .fudoFont(.caption(12))
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
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
        } else {
            let up = rounded > 0
            Label("\(up ? "+" : "")\(rounded) OVR", systemImage: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .fudoFont(.caption(12, weight: .semibold))
                .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
                .labelStyle(.titleAndIcon)
        }
    }
}
