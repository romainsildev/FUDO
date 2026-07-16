import SwiftUI

/// OB 13 — the second OVR beat. The future becomes a DATE. Not "you'll improve":
/// "on August 10, you'll be at ~78". An exact number on an exact day is a
/// verifiable promise — the opposite of a motivation quote, and the micro-line
/// says so out loud.
struct ProjectionScreen: View {
    let base: Double
    let days: Int
    let projectedOVR: Double
    let projectedRank: Rank
    let date: Date
    let onAdvance: () -> Void

    @State private var drawnDays = 0
    @State private var revealed = false

    private static let drawDuration: TimeInterval = 0.6
    private static let titleDelay: TimeInterval = 0.8
    private static let microDelay: TimeInterval = 1.0

    private var displayedProjection: Int { OVREngine.displayedOVR(projectedOVR) }

    var body: some View {
        OnboardingScaffold(step: .projection, eyebrow: "YOUR TRAJECTORY",
                           title: "On \(OnboardingCopy.longDate(date)), you will be\nat ~\(displayedProjection).",
                           canAdvance: true, onAdvance: onAdvance) {
            EmptyView()
        }
        // The card sits ABOVE the title on this screen (frame): the curve is the
        // subject, the sentence is its caption.
        .overlay(alignment: .top) { curveCard }
        .task { await runDraw() }
    }

    private var curveCard: some View {
        ProjectionCurveView(base: base, days: days,
                            rankName: projectedRank.displayName,
                            drawnDays: drawnDays)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.top, 96)
            .opacity(revealed ? 1 : 0)
    }

    /// The line draws itself left to right, then the endpoint lands with the beat.
    private func runDraw() async {
        revealed = true
        withAnimation(.easeOut(duration: Self.drawDuration)) { drawnDays = days }
        try? await Task.sleep(for: .seconds(Self.drawDuration))
        Haptics.medium()
    }
}

#if DEBUG
/// Every number here comes from OVREngine — including the rank, which is why 78
/// reads WARRIOR and not the frame's "MASTER".
private struct ProjectionPreviewHost: View {
    let base: Double
    let days: Int

    var body: some View {
        let projected = OVREngine.project(from: base, days: days)
        let date = Calendar.current.date(byAdding: .day, value: days - 1, to: .now) ?? .now
        return OnboardingPreviewChrome {
            ProjectionScreen(base: base, days: days, projectedOVR: projected,
                             projectedRank: OVREngine.rank(forOVR: projected),
                             date: date, onAdvance: {})
        }
    }
}

/// The canonical run: 43 → ~78 in 30 days. Warrior.
#Preview("OB 13 — 43 → ~78 (30 days)") {
    ProjectionPreviewHost(base: 43, days: 30)
}

/// 90 perfect days from the floor — the steepest promise the funnel can make.
#Preview("OB 13 — 40 → ~96 (Hardcore 90)") {
    ProjectionPreviewHost(base: 40, days: 90)
}

/// The flattest: a disciplined starter over 30 days.
#Preview("OB 13 — 50 → ~81 (30 days)") {
    ProjectionPreviewHost(base: 50, days: 30)
}
#endif
