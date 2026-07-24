import SwiftUI
import Charts

/// The Stats graph (2026-07-24 — bars replaced by a curve, Romain's call): checks per
/// day over the window as one cream line joining the day points. The best day(s) get a
/// gold point and its count — never red: a light day is not a failure. ≤7 days shows
/// weekday labels under the plot; longer windows hide the axis and show DAY 1 / DAY N.
struct ChecksPerDayCard: View {
    let days: [DayChecks]
    let maxChecks: Int

    private var isWide: Bool { days.count <= 7 }
    private var byDay: [Date: DayChecks] {
        Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if days.count >= 2 {
                chart
                if !isWide { axisFooter }
            } else {
                caption
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack {
            Text("CHECKS PER DAY")
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            Text("MAX \(maxChecks)")
                .fudoFont(.label(10))
                .kerning(0.8)
                .foregroundStyle(FudoColor.textSecondary.opacity(0.7))
        }
    }

    private var caption: some View {
        Text("Check your first days in and the curve starts.")
            .fudoFont(.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            // The "full day" ceiling — a quiet dashed line at max checks.
            RuleMark(y: .value("Max", maxChecks))
                .foregroundStyle(FudoColor.textSecondary.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 5]))

            ForEach(days) { day in
                LineMark(x: .value("Day", day.date), y: .value("Checks", day.checks))
                    .foregroundStyle(FudoColor.textPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }

            ForEach(days) { day in
                PointMark(x: .value("Day", day.date), y: .value("Checks", day.checks))
                    .symbolSize(day.isBest ? 80 : 28)
                    .foregroundStyle(day.isBest ? FudoColor.celebrationGold : FudoColor.textPrimary)
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                        if day.isBest {
                            Text("\(day.checks)")
                                .fudoFont(.label(11, weight: .semibold))
                                .foregroundStyle(FudoColor.celebrationGold)
                        }
                    }
            }
        }
        .chartYScale(domain: 0...(Double(maxChecks) + 0.6))
        .chartYAxis(.hidden)
        .chartXAxis {
            if isWide {
                AxisMarks(values: days.map(\.date)) { value in
                    AxisValueLabel(anchor: .top) {
                        if let date = value.as(Date.self), let day = byDay[date] {
                            Text(day.label)
                                .fudoFont(.label(10, weight: .semibold))
                                .foregroundStyle(day.isBest ? FudoColor.celebrationGold
                                                            : FudoColor.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(height: 130)
    }

    private var axisFooter: some View {
        HStack {
            Text("DAY 1")
            Spacer()
            Text("DAY \(days.count)")
        }
        .fudoFont(.label(9))
        .kerning(0.8)
        .foregroundStyle(FudoColor.textSecondary.opacity(0.7))
    }
}
