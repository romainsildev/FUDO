import SwiftUI

/// The OVR history as vermillon bars (02 Progression, 2026-07-24 — Romain's re-skin,
/// replaces the green/red line curve). One bar per day over the run window, height scaled
/// to the window's own min…max so the climb reads even across a narrow OVR range. The most
/// recent third burns bright accent; older days sit in deep vermillon. Vermillon is the
/// identity metric's colour here (OVR), not habit-success data — that stays cream (Stats).
struct OVRBarsView: View {
    let points: [CurvePoint]
    let windowLabel: String
    let weekNet: Int?

    private let plotHeight: CGFloat = 64
    private let minBar: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if points.count >= 2 { bars } else { caption }
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
            Text(windowLabel.uppercased())
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            if let weekNet, weekNet != 0 {
                let up = weekNet > 0
                Label("\(up ? "+" : "")\(weekNet) this week",
                      systemImage: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .fudoFont(.caption(13, weight: .semibold))
                    .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var caption: some View {
        Text("Your OVR history fills in as the challenge goes. Come back tomorrow.")
            .fudoFont(.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: plotHeight, alignment: .leading)
    }

    private var bars: some View {
        let values = points.map(\.value)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, 1)
        let recentCount = max(points.count / 3, 1)
        let firstRecent = points.count - recentCount

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                let ratio = (point.value - lo) / span
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(index >= firstRecent ? FudoColor.accent : FudoColor.accentDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: minBar + CGFloat(ratio) * plotHeight)
            }
        }
        .frame(height: plotHeight + minBar, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("OVR bars") {
    // A 13-day climb 47 → 59 with a couple of dips, like a real run.
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let values: [Double] = [47, 48, 48, 50, 51, 50, 53, 54, 55, 54, 57, 58, 59]
    let points: [CurvePoint] = values.enumerated().map { i, v in
        CurvePoint(id: i, date: base.addingTimeInterval(Double(i) * 86_400), value: v,
                   delta: i == 0 ? 0 : v - values[i - 1], isComplete: nil)
    }
    return OVRBarsView(points: points, windowLabel: "Last 13 days", weekNet: 5)
        .padding(FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FudoColor.bgPrimary)
        .preferredColorScheme(.dark)
}
#endif
