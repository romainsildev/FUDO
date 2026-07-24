import SwiftUI

/// The Stats graph (2026-07-24 — 3D isometric bars, Figma "PREVIEW P1 — Iso bars",
/// Romain's re-skin): checks per day as a little 3D bar field. Bars carry the acted data
/// palette (Romain over the mock's heat gradient): cream by default, GOLD on the best
/// day(s) with its count, RED only on a closed zero-check day (a real miss — the only red
/// on this card). ≤7 days shows weekday labels; longer windows hide them and show
/// DAY 1 / DAY N. Hand-drawn (Canvas) because Swift Charts has no isometric bar.
struct ChecksPerDayCard: View {
    let days: [DayChecks]
    let maxChecks: Int

    private var isWide: Bool { days.count <= 7 }
    private let plotHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if days.isEmpty {
                caption
            } else {
                plot
                if isWide { labelsRow } else { axisFooter }
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
        Text("Check your first days in and the bars start.")
            .fudoFont(.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    /// The 3D isometric bar field. Each column gets an equal slot (`maxWidth: .infinity`),
    /// so the labels row below lines up under the bars for free.
    private var plot: some View {
        GeometryReader { geo in
            let slot = geo.size.width / CGFloat(max(days.count, 1))
            let barWidth = min(slot * 0.5, 22)
            HStack(spacing: 0) {
                ForEach(days) { day in
                    IsoBarColumn(day: day, maxChecks: maxChecks,
                                 barWidth: barWidth, plotHeight: geo.size.height)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: plotHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FudoColor.textPrimary.opacity(0.06)).frame(height: 1)
        }
    }

    private var labelsRow: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                Text(day.label)
                    .fudoFont(.label(10, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(day.isBest ? FudoColor.celebrationGold
                                     : day.isMissed ? FudoColor.negative
                                     : FudoColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
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

// MARK: - One column

/// One bar column: the 3D bar bottom-anchored in the plot, plus the count above the best
/// bar. A closed zero-check day gets a short red stub so the miss is still visible.
private struct IsoBarColumn: View {
    let day: DayChecks
    let maxChecks: Int
    let barWidth: CGFloat
    let plotHeight: CGFloat

    private var depthX: CGFloat { barWidth * 0.5 }
    private var depthY: CGFloat { barWidth * 0.3 }
    private let topInset: CGFloat = 18   // headroom for the value label + top face

    private var baseColor: Color {
        if day.isBest { return FudoColor.celebrationGold }
        if day.isMissed { return FudoColor.negative }
        return FudoColor.textPrimary
    }

    private var barHeight: CGFloat {
        if day.checks == 0 { return day.isMissed ? 6 : 0 }   // red stub for a real miss
        let ratio = maxChecks > 0 ? CGFloat(day.checks) / CGFloat(maxChecks) : 0
        return max(ratio * (plotHeight - topInset), 8)
    }

    var body: some View {
        let height = barHeight
        ZStack(alignment: .bottom) {
            if height > 0 {
                IsoBar(width: barWidth, depthX: depthX, depthY: depthY,
                       height: height, base: baseColor)
                    .frame(width: barWidth + depthX, height: plotHeight, alignment: .bottom)
            }
            if day.isBest {
                Text("\(day.checks)")
                    .fudoFont(.label(11, weight: .bold))
                    .foregroundStyle(FudoColor.celebrationGold)
                    .offset(x: depthX / 2, y: -(height + depthY + 4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.label): \(day.checks) checks\(day.isBest ? ", best day" : "")")
    }
}

// MARK: - The isometric bar

/// Three faces of an extruded bar: front (base), a darker right side, a lighter top. The
/// glazes (white/black over the base) keep the base colour pure while reading as 3D.
private struct IsoBar: View {
    let width: CGFloat
    let depthX: CGFloat
    let depthY: CGFloat
    let height: CGFloat
    let base: Color

    var body: some View {
        Canvas { ctx, size in
            let baseY = size.height
            let topY = baseY - height
            let w = width, dx = depthX, dy = depthY

            // Front face.
            let front = Path(CGRect(x: 0, y: topY, width: w, height: height))
            ctx.fill(front, with: .color(base.opacity(0.9)))

            // Right side — darker.
            var side = Path()
            side.move(to: CGPoint(x: w, y: topY))
            side.addLine(to: CGPoint(x: w + dx, y: topY - dy))
            side.addLine(to: CGPoint(x: w + dx, y: baseY - dy))
            side.addLine(to: CGPoint(x: w, y: baseY))
            side.closeSubpath()
            ctx.fill(side, with: .color(base.opacity(0.9)))
            ctx.fill(side, with: .color(.black.opacity(0.28)))

            // Top — lighter.
            var top = Path()
            top.move(to: CGPoint(x: 0, y: topY))
            top.addLine(to: CGPoint(x: w, y: topY))
            top.addLine(to: CGPoint(x: w + dx, y: topY - dy))
            top.addLine(to: CGPoint(x: dx, y: topY - dy))
            top.closeSubpath()
            ctx.fill(top, with: .color(base.opacity(0.9)))
            ctx.fill(top, with: .color(.white.opacity(0.16)))
        }
    }
}

#if DEBUG
#Preview("Checks per day — 3D iso") {
    // Figma frame heights: M3 T2 W3 T3 F5(best) S3 S4, plus a missed-day variant.
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let counts = [3, 2, 3, 3, 5, 3, 4]
    let labels = ["M", "T", "W", "T", "F", "S", "S"]
    let days: [DayChecks] = counts.enumerated().map { i, c in
        DayChecks(id: i, date: base.addingTimeInterval(Double(i) * 86_400),
                  label: labels[i], checks: c, isBest: c == 5, isMissed: false)
    }
    return VStack(spacing: 16) {
        ChecksPerDayCard(days: days, maxChecks: 5)
        ChecksPerDayCard(days: days.enumerated().map { i, d in
            DayChecks(id: d.id, date: d.date, label: d.label,
                      checks: i == 1 ? 0 : d.checks, isBest: d.isBest,
                      isMissed: i == 1)
        }, maxChecks: 5)
    }
    .padding(FudoSpacing.screenMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}
#endif
