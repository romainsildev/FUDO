import SwiftUI

/// OB 13 — the second OVR beat. The future becomes a DATE. Not "you'll improve":
/// "on SEPTEMBER 14, you'll be at ~91" — the date giant in Bebas, the number
/// vermillon, the rank stamped next to it. An exact number on an exact day is a
/// verifiable promise, and the micro-line under the curve says so out loud.
///
/// Three STRICT phases (batch #5 — the old loader was an `.overlay` ON the
/// content, so the flow's move+opacity insertion rendered the whole subtree
/// semi-transparent and the headline ghosted THROUGH the "opaque" cover):
///   1. locking — a dedicated screen: glass pill only, the projection content
///      is ABSENT from the hierarchy (not opacity-0), the bar hidden (loader rule).
///   2. blank — the loader's fade-out FINISHES before anything enters.
///   3. reveal — one staggered pass: headline fade+rise, curve draw-in, CTA last.
/// The beat plays once per run (batch #4 pattern): a re-entry poses the
/// revealed state cold at init, so not even one frame of the loader can flash.
struct ProjectionScreen: View {
    let base: Double
    let days: Int
    let projectedOVR: Double
    let projectedRank: Rank
    let date: Date
    let hasPlayed: Bool
    let onPlayed: () -> Void
    let onAdvance: () -> Void

    private enum Phase { case locking, blank, reveal }
    private typealias Metrics = OnboardingMetrics.Projection

    @State private var phase: Phase
    @State private var headlineShown: Bool
    @State private var curveShown: Bool
    @State private var drawProgress: CGFloat
    @State private var landed: Bool
    @State private var ctaShown: Bool

    init(base: Double, days: Int, projectedOVR: Double, projectedRank: Rank,
         date: Date, hasPlayed: Bool, onPlayed: @escaping () -> Void,
         onAdvance: @escaping () -> Void) {
        self.base = base
        self.days = days
        self.projectedOVR = projectedOVR
        self.projectedRank = projectedRank
        self.date = date
        self.hasPlayed = hasPlayed
        self.onPlayed = onPlayed
        self.onAdvance = onAdvance
        let settled = hasPlayed
        _phase = State(initialValue: settled ? .reveal : .locking)
        _headlineShown = State(initialValue: settled)
        _curveShown = State(initialValue: settled)
        _drawProgress = State(initialValue: settled ? 1 : 0)
        _landed = State(initialValue: settled)
        _ctaShown = State(initialValue: settled)
    }

    private var displayedProjection: Int { OVREngine.displayedOVR(projectedOVR) }

    var body: some View {
        ZStack {
            switch phase {
            case .locking:
                lockingBeat
                    .transition(.opacity)
            case .blank:
                Color.clear
            case .reveal:
                reveal
                    .transition(.opacity)
            }
        }
        .task { await run() }
    }

    // MARK: - Phase 1 — the locking beat

    /// A dedicated loader screen — the glass pill of OB 12's exit, centered,
    /// nothing else. No headline in this hierarchy: nothing can ghost through
    /// a view that doesn't exist.
    private var lockingBeat: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            Text("Locking your protocol…")
                .fudoFont(.headline(15))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .fudoGlassCapsule(shadow: false)
        }
    }

    // MARK: - Phase 3 — the reveal

    private var reveal: some View {
        OnboardingScaffold(step: .projection, canAdvance: true,
                           ctaVisible: ctaShown, centersVertically: true,
                           onAdvance: onAdvance) {
            VStack(spacing: 0) {
                headline
                    .opacity(headlineShown ? 1 : 0)
                    .offset(y: headlineShown ? 0 : 12)

                ProjectionCurveView(base: base, days: days,
                                    progress: drawProgress, landed: landed)
                    .padding(.top, 36)
                    .opacity(curveShown ? 1 : 0)

                Text("Exact date. Real number. No motivation quotes.")
                    .fudoFont(.caption(12))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 14)
                    .opacity(curveShown ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }

    /// The date is the hero — the welcome hooks' internal-scale grammar: small
    /// lead, giant Bebas date, then the number line with the rank stamped next
    /// to it. Never again an orphaned "at ~91." on its own line.
    private var headline: some View {
        VStack(spacing: 8) {
            Text("ON")
                .fudoFont(.onboardingDisplay(Metrics.leadSize))
                .foregroundStyle(FudoColor.textSecondary)
            Text(OnboardingCopy.longDate(date).uppercased())
                .fudoFont(.onboardingDisplay(Metrics.dateSize))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(OnboardingMetrics.Hook.minimumScale)
            HStack(spacing: 10) {
                // ONE .fudoFont on the combined Text — a Font per segment kills
                // Dynamic Type (batch #4 pitfall).
                (Text("you'll be at ").foregroundStyle(FudoColor.textPrimary)
                 + Text("~\(displayedProjection)").foregroundStyle(FudoColor.accent))
                    .fudoFont(.title(24, weight: .bold))
                rankChip
            }
            .padding(.top, 6)
        }
    }

    /// Rank badge grounds: `accentDeep`, palette rule.
    private var rankChip: some View {
        Text(projectedRank.displayName.uppercased())
            .fudoFont(.stat(12))
            .foregroundStyle(FudoColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background { Capsule().fill(FudoColor.accentDeep) }
    }

    // MARK: - Choreography

    /// Dwell → loader OUT (fade finished) → blank breath → reveal in one
    /// staggered pass. Cancellation guard after every sleep (batch #3 pattern):
    /// a screen torn down mid-beat fires nothing.
    private func run() async {
        guard !hasPlayed else { return }

        try? await Task.sleep(for: .seconds(Metrics.lockingBeat))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: Metrics.loaderFade)) { phase = .blank }

        try? await Task.sleep(for: .seconds(Metrics.loaderFade + Metrics.blankGap))
        guard !Task.isCancelled else { return }
        withAnimation(AppAnimation.standard) {
            phase = .reveal
            headlineShown = true
            // The bar returns WITH the reveal — same transaction, one motion.
            onPlayed()
        }

        try? await Task.sleep(for: .seconds(Metrics.curveDelay))
        guard !Task.isCancelled else { return }
        withAnimation(AppAnimation.standard) { curveShown = true }
        withAnimation(.easeOut(duration: Metrics.draw)) { drawProgress = 1 }

        try? await Task.sleep(for: .seconds(Metrics.draw))
        guard !Task.isCancelled else { return }
        Haptics.medium()
        withAnimation(AppAnimation.standard) {
            landed = true
            ctaShown = true
        }
    }
}

#if DEBUG
/// Every number here comes from OVREngine — including the rank, which is why 78
/// reads WARRIOR and not the frame's "MASTER".
private struct ProjectionPreviewHost: View {
    let base: Double
    let days: Int
    var hasPlayed = false

    var body: some View {
        let projected = OVREngine.project(from: base, days: days)
        let date = Calendar.current.date(byAdding: .day, value: days - 1, to: .now) ?? .now
        return OnboardingPreviewChrome {
            ProjectionScreen(base: base, days: days, projectedOVR: projected,
                             projectedRank: OVREngine.rank(forOVR: projected),
                             date: date, hasPlayed: hasPlayed, onPlayed: {},
                             onAdvance: {})
        }
    }
}

/// The canonical run, full choreography: locking beat → reveal → draw-in.
#Preview("OB 13 — 43 → ~78 (30 days)") {
    ProjectionPreviewHost(base: 43, days: 30)
}

/// 90 perfect days from the floor — the steepest promise, five rank ticks.
#Preview("OB 13 — 40 → ~96 (Hardcore 90)") {
    ProjectionPreviewHost(base: 40, days: 90)
}

/// Re-entry: the revealed state posed cold — no loader, no replay.
#Preview("OB 13 — already played") {
    ProjectionPreviewHost(base: 43, days: 30, hasPlayed: true)
}
#endif
