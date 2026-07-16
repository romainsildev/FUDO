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
    @State private var locking = true

    private static let drawDuration: TimeInterval = 0.6
    /// The short beat replacing the old pre-projection loader (restructure
    /// 2026-07-16: the narrative loader moved before the reveal): one breath of
    /// "Locking…", never more than a second.
    private static let lockingBeat: TimeInterval = 0.9

    private var displayedProjection: Int { OVREngine.displayedOVR(projectedOVR) }

    /// Title on top, curve below, the whole block centered like OB 06/09/10 —
    /// layout fix 2026-07-16: the old top-overlay card sat ON the title and left
    /// the lower two-thirds of the screen dead. Nothing overlaps in a VStack.
    var body: some View {
        OnboardingScaffold(step: .projection,
                           title: "On \(OnboardingCopy.longDate(date)), you will be\nat ~\(displayedProjection).",
                           canAdvance: true, centersVertically: true, onAdvance: onAdvance) {
            ProjectionCurveView(base: base, days: days,
                                rankName: projectedRank.displayName,
                                drawnDays: drawnDays)
                .padding(.top, 28)
                .opacity(revealed ? 1 : 0)
        }
        .overlay {
            if locking {
                ZStack {
                    FudoColor.bgPrimary.ignoresSafeArea()
                    Text("Locking your protocol…")
                        .fudoFont(.body(15))
                        .foregroundStyle(FudoColor.textPrimary)
                        .opacity(0.45)
                }
                .transition(.opacity)
            }
        }
        .task { await runDraw() }
    }

    /// One "Locking…" breath, then the line draws itself left to right and the
    /// endpoint lands with the beat.
    private func runDraw() async {
        try? await Task.sleep(for: .seconds(Self.lockingBeat))
        withAnimation(AppAnimation.standard) { locking = false }
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
