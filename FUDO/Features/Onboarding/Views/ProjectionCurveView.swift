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
///
/// Batch #5 upgrade: the FULL curve renders once — a vermillon gradient pooled
/// under the line, a rank tick at every floor the climb crosses (Rank.floorOVR,
/// never a hard-coded threshold), the gray start dot and a vermillon endpoint
/// with a quiet pulse. The reveal is a leading-edge MASK driven by `progress`,
/// so the line and everything riding it draw left → right in one true pass.
struct ProjectionCurveView: View {
    let base: Double
    let days: Int
    /// 0…1 — how much of the climb is unmasked. Animated by the screen.
    var progress: CGFloat
    /// Endpoint landed — mounts the pulse. Separate from `progress` because a
    /// state's final VALUE is posed the instant the animation starts; only the
    /// presentation interpolates. The pulse must wait for the line to arrive.
    var landed: Bool

    private static let cardHeight: CGFloat = 190
    private static let lineWidth: CGFloat = 3
    private static let areaGradient = LinearGradient(
        colors: [FudoColor.accent.opacity(0.22), FudoColor.accent.opacity(0)],
        startPoint: .top, endPoint: .bottom)

    private struct Point: Identifiable {
        let id: Int
        let day: Int
        let ovr: Double
    }

    private struct RankTick: Identifiable {
        let id: Int
        let day: Int
        let ovr: Double
        let name: String
    }

    /// How far the day-to-day rhythm swings around the engine's pace (0…<1 —
    /// below 1 keeps every increment positive, so the climb stays monotone).
    private static let paceAmplitude = 0.55

    /// The engine's climb, re-paced for the eye (device feedback 2026-07-17:
    /// the smooth glide read as fake). The TOTAL and both endpoints are the
    /// engine's, untouched — only the day-to-day rhythm is modulated, because
    /// a real run has flat days and strong days. Deterministic by construction
    /// (composed sines, phase seeded by `base`): a computed property re-runs on
    /// every render and the curve must never jitter.
    private var points: [Point] {
        let engine = (0...days).map { OVREngine.project(from: base, days: $0) }
        let total = (engine.last ?? base) - base
        guard days >= 2, total > 0 else {
            return engine.enumerated().map { Point(id: $0.offset, day: $0.offset, ovr: $0.element) }
        }

        // ~4 organic waves whatever the duration; incommensurate frequencies so
        // the pattern never reads as a repeat, `base` in the phase so two runs
        // don't share the same fingerprint.
        func pace(_ day: Int) -> Double {
            let t = Double(day) / Double(days)
            return 1 + Self.paceAmplitude * sin(t * 26 + base + 2.4 * sin(t * 7 + 1))
        }

        let modulated = (1...days).map { (engine[$0] - engine[$0 - 1]) * pace($0) }
        // Re-normalized so the drawn climb lands EXACTLY on the engine's number.
        let scale = total / modulated.reduce(0, +)
        var running = base
        var climb = [Point(id: 0, day: 0, ovr: base)]
        for day in 1...days {
            running += modulated[day - 1] * scale
            climb.append(Point(id: day, day: day, ovr: running))
        }
        return climb
    }

    private var endOVR: Double { points.last?.ovr ?? base }

    /// Every rank floor the climb crosses, pinned to its first crossing day on
    /// the DRAWN curve (the tick must sit on the line the eye follows). The
    /// final rank is excluded: the headline chip and the endpoint dot already
    /// carry it — a third marker glued to the pulse is noise (device feedback).
    private var rankTicks: [RankTick] {
        let climb = points
        let finalRank = OVREngine.rank(forOVR: endOVR)
        return Rank.allCases.compactMap { rank in
            guard rank != finalRank,
                  rank.floorOVR > base, rank.floorOVR <= endOVR,
                  let crossing = climb.first(where: { $0.ovr >= rank.floorOVR }),
                  crossing.day < days
            else { return nil }
            return RankTick(id: rank.rawValue, day: crossing.day,
                            ovr: crossing.ovr, name: rank.displayName)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    var body: some View {
        chart
            .mask {
                // The leading-edge sweep — scaleEffect is animatable, so the
                // draw follows the screen's single withAnimation.
                Rectangle()
                    .scaleEffect(x: max(progress, 0.0001), y: 1, anchor: .leading)
            }
            .overlay(alignment: .bottomLeading) {
                // Outside the mask: "today" is a fact, not part of the promise
                // being drawn.
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
            ForEach(points) { point in
                AreaMark(x: .value("Day", point.day), y: .value("OVR", point.ovr))
                    .foregroundStyle(Self.areaGradient)
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", point.day), y: .value("OVR", point.ovr))
                    .foregroundStyle(FudoColor.accent)
                    .lineStyle(StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .interpolationMethod(.monotone)
            }

            ForEach(rankTicks) { tick in
                PointMark(x: .value("Day", tick.day), y: .value("OVR", tick.ovr))
                    .symbolSize(26)
                    .foregroundStyle(FudoColor.textPrimary)
                    // Top-leading: on a rising curve the area above-left of any
                    // point is ALWAYS empty — the label never touches the line
                    // (device feedback: .bottom sat right on it). Fit-to-plot
                    // keeps the earliest tick from bleeding off the left edge.
                    .annotation(position: .topLeading, spacing: 6,
                                overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                        Text(tick.name.uppercased())
                            .fudoFont(.caption(9))
                            .foregroundStyle(FudoColor.textSecondary)
                    }
            }

            PointMark(x: .value("Day", 0), y: .value("OVR", base))
                .symbolSize(60)
                .foregroundStyle(FudoColor.textSecondary)

            PointMark(x: .value("Day", days), y: .value("OVR", endOVR))
                .symbolSize(110)
                .foregroundStyle(FudoColor.accent)
        }
        // The domain is fixed so the line GROWS across the card instead of the
        // card re-scaling under it — the climb reads as a climb. The plot keeps
        // an edge inset so the start dot and the endpoint pulse render WHOLE
        // instead of half-clipped at the card's borders (device feedback).
        .chartXScale(domain: 0...days, range: .plotDimension(padding: 10))
        .chartYScale(domain: (base - 4)...(endOVR + 4))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in pulseOverlay(proxy) }
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    /// The endpoint's quiet pulse, anchored through the chart's own geometry —
    /// the proxy speaks plot-area coordinates, the plot frame translates them.
    @ViewBuilder private func pulseOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if landed,
               let plotFrame = proxy.plotFrame,
               let x = proxy.position(forX: Double(days)),
               let y = proxy.position(forY: endOVR) {
                let origin = geo[plotFrame].origin
                EndpointPulse()
                    .position(x: origin.x + x, y: origin.y + y)
            }
        }
        .allowsHitTesting(false)
    }
}

/// An expanding ring dying at the endpoint — the promise's heartbeat. Slow-breath
/// family (hintPulse tempo), never a blink.
private struct EndpointPulse: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(FudoColor.accent, lineWidth: 1.5)
            .frame(width: 14, height: 14)
            .scaleEffect(expanded ? 2.4 : 1)
            .opacity(expanded ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: OnboardingMetrics.hintPulse)
                    .repeatForever(autoreverses: false)) { expanded = true }
            }
    }
}
