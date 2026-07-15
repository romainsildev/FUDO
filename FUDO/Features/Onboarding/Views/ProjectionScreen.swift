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
    let onBack: () -> Void

    @State private var drawnDays = 0
    @State private var revealed = false

    private static let drawDuration: TimeInterval = 0.6
    private static let titleDelay: TimeInterval = 0.8
    private static let microDelay: TimeInterval = 1.0

    private var displayedProjection: Int { OVREngine.displayedOVR(projectedOVR) }

    var body: some View {
        OnboardingScaffold(step: .projection, eyebrow: "YOUR TRAJECTORY",
                           title: "On \(OnboardingCopy.longDate(date)), you will be\nat ~\(displayedProjection).",
                           canAdvance: true, onBack: onBack, onAdvance: onAdvance) {
            EmptyView()
        }
        // The card sits ABOVE the title on this screen (frame): the curve is the
        // subject, the sentence is its caption.
        .overlay(alignment: .top) { curveCard }
        .task { await runDraw() }
    }

    private var curveCard: some View {
        ProjectionCurveView(base: base, days: days,
                            rankName: ProgressionRankNaming.name(for: projectedRank),
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
