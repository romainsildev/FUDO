import SwiftUI

/// The narrative ANALYSIS loader (RiteOff 13_LoadingView transposed to FUDO
/// tokens; restructure 2026-07-16: it sits between the quiz and the OVR
/// reveal). A vermillon ring fills while HIS OWN numbers orbit it and a
/// four-step timeline ticks below; at 100 % the percent gives way to a check,
/// the ring pops, and a glass pill — "Access your report" — waits for HIS tap.
/// The user drives the exit; nothing auto-advances.
///
/// OB 19 keeps the plain `OnboardingLoaderScreen` (auto-advance + the real
/// challenge-creation work); this screen is pure theater and creates nothing.
struct BuildLoaderScreen: View {
    let stats: [OnboardingCopy.LoaderStat]
    let steps: [String]
    /// Batch #10: the analysis no longer auto-starts. `hasStarted` (from the VM)
    /// is the one-shot memory — false shows the waiting state + CTA, true means
    /// he already tapped (a re-render must not drop him back to waiting).
    var hasStarted = false
    var onStart: () -> Void = {}
    let onAdvance: () -> Void

    /// waiting → he hasn't tapped; running → the theater plays; the pill appears
    /// at the end of `finish()`.
    private enum Phase { case waiting, running }
    @State private var phase: Phase = .waiting

    // MARK: Timing (fill = OnboardingMetrics.buildLoaderDuration)

    private static let fill: TimeInterval = OnboardingMetrics.buildLoaderDuration
    private static let spawnOffsets: [TimeInterval] = [1.0, 2.4, 3.8, 5.2, 6.0]
    private static let statLifetime: TimeInterval = 2.4
    private static let statFade: TimeInterval = 0.5
    private static let checkDwell: TimeInterval = 0.4

    // MARK: Geometry

    private static let ringSize: CGFloat = 220
    private static let ringLineWidth: CGFloat = 6   // FUDO rings: 6 pt, round cap
    /// Fixed orbital slots (angle°, radius) — deterministic, pre-cleared of the
    /// title band and of each other; no runtime collision solving.
    private static let slots: [(angle: Double, radius: CGFloat)] = [
        (200, 126), (140, 134), (310, 122), (180, 142), (55, 132)
    ]

    @State private var runBegan = false
    @State private var progress: Double = 0
    @State private var percent = 0
    @State private var stepStates: [BuildBullet.State]
    @State private var visibleStats: [PlacedStat] = []

    // Climax — the three center layers cross-fade, never hard-swap.
    @State private var percentOpacity: Double = 1
    @State private var checkShown = false
    @State private var ringScale: CGFloat = 1
    @State private var pillShown = false
    @State private var pillBreath: Double = 1

    private struct PlacedStat: Identifiable {
        let id = UUID()
        let stat: OnboardingCopy.LoaderStat
        let angle: Double
        let radius: CGFloat
    }

    init(stats: [OnboardingCopy.LoaderStat], steps: [String],
         hasStarted: Bool = false, onStart: @escaping () -> Void = {},
         onAdvance: @escaping () -> Void) {
        self.stats = stats
        self.steps = steps
        self.hasStarted = hasStarted
        self.onStart = onStart
        self.onAdvance = onAdvance
        _stepStates = State(initialValue: Array(repeating: .idle, count: steps.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("ANALYZING\nYOUR ANSWERS")
                .fudoFont(.onboardingDisplay(48))
                .foregroundStyle(FudoColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 52)

            Spacer(minLength: 0)

            ring

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    BuildBullet(text: steps[index], state: stepStates[index],
                                isFirst: index == 0, isLast: index == steps.count - 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(phase == .waiting ? 0.4 : 1)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Consent gate (batch #10): the theater waits for HIS tap.
        .safeAreaInset(edge: .bottom) {
            if phase == .waiting { analyzeCTA }
        }
        .task { await bootstrap() }
    }

    /// The primary CTA that launches the analysis — the perceived-consent beat.
    private var analyzeCTA: some View {
        Button {
            onStart()
            phase = .running
            Task { await run() }
        } label: {
            Text("Analyze my answers")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    /// One-shot: if he already tapped (VM remembers), skip the waiting state and
    /// run straight away rather than asking him to consent twice.
    private func bootstrap() async {
        if hasStarted {
            phase = .running
            await run()
        }
    }

    // MARK: - The ring and its satellites

    private var ring: some View {
        ZStack {
            // Halo — breathes with the ring, vermillon like every FUDO ring.
            Circle()
                .fill(RadialGradient(colors: [FudoColor.accent.opacity(0.10), .clear],
                                     center: .center,
                                     startRadius: Self.ringSize / 2,
                                     endRadius: Self.ringSize))
                .frame(width: Self.ringSize * 1.5, height: Self.ringSize * 1.5)

            Circle()
                .stroke(FudoColor.border, lineWidth: Self.ringLineWidth)
                .frame(width: Self.ringSize, height: Self.ringSize)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(FudoColor.accent,
                        style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: Self.ringSize, height: Self.ringSize)

            centerLabel

            ForEach(visibleStats) { placed in
                OrbitStatView(stat: placed.stat, angle: placed.angle, radius: placed.radius,
                              lifetime: Self.statLifetime, fade: Self.statFade)
            }
        }
        .scaleEffect(ringScale)
        .frame(height: Self.ringSize * 1.5)
    }

    /// Percent → check → pill: all three live in the tree, blended by opacity,
    /// so the climax reads as one continuous motion.
    private var centerLabel: some View {
        ZStack {
            Text("\(percent)%")
                .fudoFont(.stat(30))
                .foregroundStyle(FudoColor.textPrimary)
                .opacity(percentOpacity)
                .allowsHitTesting(false)

            // Validation check — the acted green exception (validation badges).
            Image(systemName: "checkmark")
                .fudoFont(.glyph(44, weight: .heavy))
                .foregroundStyle(FudoColor.positive)
                .opacity(checkShown ? 1 : 0)
                .scaleEffect(checkShown ? 1 : 0.4)
                .allowsHitTesting(false)

            accessReportPill
                .opacity(pillShown ? pillBreath : 0)
                .scaleEffect(pillShown ? 1 : 0.92)
                .disabled(!pillShown)
        }
    }

    private var accessReportPill: some View {
        Button {
            Haptics.heavy()
            onAdvance()
        } label: {
            HStack(spacing: 6) {
                Text("Access your report")
                    .fudoFont(.headline(15))
                    .foregroundStyle(FudoColor.textPrimary)
                Image(systemName: "chevron.right")
                    .fudoFont(.glyph(11, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .fudoGlassCapsule(shadow: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Choreography

    private func run() async {
        guard !runBegan else { return }
        runBegan = true
        stepStates[0] = .active

        async let percentDrive: Void = drivePercent()
        async let bulletDrive: Void = driveBullets()
        async let statDrive: Void = driveStats()
        _ = await (percentDrive, bulletDrive, statDrive)
    }

    private func drivePercent() async {
        withAnimation(.easeInOut(duration: Self.fill)) { progress = 1 }
        let ticks = Int(Self.fill * 30)
        for tick in 1...ticks {
            try? await Task.sleep(for: .seconds(Self.fill / Double(ticks)))
            let t = Double(tick) / Double(ticks)
            percent = Int((easeInOut(t) * 100).rounded())
        }
        percent = 100
        await finish()
    }

    private func driveBullets() async {
        let gap = Self.fill / Double(steps.count)
        for index in steps.indices {
            try? await Task.sleep(for: .seconds(gap))
            withAnimation(AppAnimation.standard) { stepStates[index] = .done }
            if index + 1 < steps.count {
                stepStates[index + 1] = .active
                Haptics.light()
            }
        }
    }

    private func driveStats() async {
        for (index, stat) in stats.prefix(Self.slots.count).enumerated() {
            let wait = index == 0
                ? Self.spawnOffsets[0]
                : Self.spawnOffsets[index] - Self.spawnOffsets[index - 1]
            try? await Task.sleep(for: .seconds(wait))
            let slot = Self.slots[index]
            let placed = PlacedStat(stat: stat, angle: slot.angle, radius: slot.radius)
            visibleStats.append(placed)

            Task {
                try? await Task.sleep(for: .seconds(Self.statLifetime + 2 * Self.statFade))
                visibleStats.removeAll { $0.id == placed.id }
            }
        }
    }

    /// 100 % → check springs in → dwell → check out + ring pop → pill in,
    /// then a quiet breathing loop. `onAdvance` fires on HIS tap only.
    private func finish() async {
        Haptics.success()
        withAnimation(.easeOut(duration: 0.25)) { percentOpacity = 0 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { checkShown = true }

        try? await Task.sleep(for: .seconds(Self.checkDwell + 0.35))
        withAnimation(.easeOut(duration: 0.3)) { checkShown = false }
        withAnimation(.easeOut(duration: 0.4)) { ringScale = 1.06 }

        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeOut(duration: 0.4)) { pillShown = true }

        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeInOut(duration: 0.5)) { ringScale = 1 }

        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
            .repeatForever(autoreverses: true)) {
            pillBreath = 0.7
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

// MARK: - Orbiting stat

/// One personalized stat emerging from the ring center to its orbital slot:
/// spring out, gentle perpendicular sway, fade away. Self-contained lifecycle.
private struct OrbitStatView: View {
    let stat: OnboardingCopy.LoaderStat
    let angle: Double
    let radius: CGFloat
    let lifetime: TimeInterval
    let fade: TimeInterval

    @State private var emerged = false
    @State private var leaving = false
    @State private var swaying = false

    var body: some View {
        let radians = Angle(degrees: angle).radians
        let x = radius * sin(radians)
        let y = -radius * cos(radians)

        capsule
            .opacity(leaving ? 0 : (emerged ? 1 : 0))
            .scaleEffect(leaving ? 0.92 : (emerged ? 1 : 0.5))
            .offset(x: emerged ? x : 0, y: emerged ? y : 0)
            .offset(y: swaying ? -4 : 4)
            .onAppear { runLifecycle() }
    }

    private var capsule: some View {
        HStack(spacing: 5) {
            if let number = stat.number {
                Text(number)
                    .fudoFont(.stat(13))
                    .foregroundStyle(stat.emphasis ? FudoColor.accent : FudoColor.textPrimary)
            }
            Text(stat.label)
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .fudoGlassCapsule(shadow: false)
    }

    private func runLifecycle() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { emerged = true }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            swaying = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5 + lifetime))
            withAnimation(.easeInOut(duration: fade)) { leaving = true }
        }
    }
}

// MARK: - Timeline bullet

/// One staged row of the build timeline — marker + thin connectors, hard snap
/// active → done with a spring pop on the done marker (RiteOff LoaderBullet
/// transposed). Internal, not private: OB 19's loader renders the SAME rows
/// (batch #10 leftover — one loader language, never two marker grammars).
struct BuildBullet: View {
    enum State { case idle, active, done }

    let text: String
    let state: State
    var isFirst = false
    var isLast = false

    private static let markerSize: CGFloat = 12
    private static let connectorHeight: CGFloat = 8

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                connector(visible: !isFirst)
                marker
                connector(visible: !isLast)
            }
            .frame(width: Self.markerSize)

            HStack(spacing: 8) {
                Text(text)
                    .fudoFont(.body(16))
                    .foregroundStyle(FudoColor.textPrimary)
                if state == .active {
                    DotsCascade()
                }
                Spacer(minLength: 0)
            }
        }
        .opacity(state == .idle ? 0.35 : 1)
    }

    private func connector(visible: Bool) -> some View {
        Rectangle()
            .fill(visible ? FudoColor.border : .clear)
            .frame(width: 1, height: Self.connectorHeight)
    }

    /// Subtle design-system markers (batch #10 — no toy checkmark): idle = hollow
    /// border ring · active = accent ring · done = filled accent dot. The same
    /// grammar as OB 19's step dots — one loader language.
    @ViewBuilder private var marker: some View {
        switch state {
        case .idle:
            Circle().stroke(FudoColor.border, lineWidth: 1)
                .frame(width: Self.markerSize, height: Self.markerSize)
        case .active:
            Circle().stroke(FudoColor.accent, lineWidth: 1.5)
                .frame(width: Self.markerSize, height: Self.markerSize)
        case .done:
            DoneMarker()
                .frame(width: Self.markerSize, height: Self.markerSize)
        }
    }
}

/// Vermillon-filled done dot, a quiet spring pop on appear — no checkmark
/// (batch #10: the toy tick read as a child's sticker). Mounted only on the
/// idle/active → done transition.
private struct DoneMarker: View {
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Circle()
            .fill(FudoColor.accent)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { scale = 1 }
            }
    }
}

/// Three dots pulsing in cascade next to the active step — opacity only.
private struct DotsCascade: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(FudoColor.textPrimary)
                    .frame(width: 4, height: 4)
                    .opacity(animating ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2), value: animating)
            }
        }
        .onAppear { animating = true }
    }
}

#if DEBUG
/// Waiting state (default): dim timeline + "Analyze my answers" CTA, no auto-start.
#Preview("Analysis loader — waiting") {
    OnboardingPreviewChrome {
        BuildLoaderScreen(
            stats: OnboardingCopy.analysisLoaderStats(draft: .previewAnswered),
            steps: ["Reading your answers",
                    "Locating your weak spot",
                    "Measuring the damage",
                    "Compiling your report"],
            onAdvance: {})
    }
}

/// Already-started (one-shot re-entry): runs straight through, no waiting CTA.
#Preview("Analysis loader — running") {
    OnboardingPreviewChrome {
        BuildLoaderScreen(
            stats: OnboardingCopy.analysisLoaderStats(draft: .previewAnswered),
            steps: ["Reading your answers",
                    "Locating your weak spot",
                    "Measuring the damage",
                    "Compiling your report"],
            hasStarted: true, onStart: {}, onAdvance: {})
    }
}
#endif
