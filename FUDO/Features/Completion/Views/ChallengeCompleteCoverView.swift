import SwiftUI

/// The end-of-challenge sequence — the app's biggest milestone, so the loudest
/// moment (confetti allowed here). Three sequential full-screen beats over the ink:
/// 1. VERDICT — days complete + an animated OVR count-up (and a sensei rank replay
///    when the run climbed a rank).
/// 2. SHARE — the auto-generated challenge-end card, Share as the primary CTA.
/// 3. HOOK — "A Warrior doesn't stop at 76." → Next challenge / Restart harder,
///    both opening the setup pre-filled; a quiet "Maybe later" drops to Home.
/// Design language mirrors `RankUpCoverView` (tokens, burst, sensei, share plumbing).
struct ChallengeCompleteCoverView: View {
    @State private var viewModel: ChallengeCompletionViewModel
    /// Dismiss without choosing a next challenge — lands on Home no-challenge.
    let onClose: () -> Void
    /// A beat-3 CTA picked a pre-filled setup — RootView swaps this cover for it.
    let onLaunch: (ChallengeSetupIntent) -> Void

    // Beat-1 animation state (seeded from the summary at init).
    @State private var displayedCount: Int
    @State private var replayRank: Rank
    @State private var appeared = false
    @State private var burstTrigger = 0
    @State private var showGain = false

    init(summary: ChallengeCompletionSummary,
         onClose: @escaping () -> Void,
         onLaunch: @escaping (ChallengeSetupIntent) -> Void) {
        _viewModel = State(initialValue: ChallengeCompletionViewModel(summary: summary))
        _displayedCount = State(initialValue: summary.startOVR)
        _replayRank = State(initialValue: summary.gainedRank ? summary.startRank : summary.endRank)
        self.onClose = onClose
        self.onLaunch = onLaunch
    }

    private var summary: ChallengeCompletionSummary { viewModel.summary }

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            glow

            Group {
                switch viewModel.beat {
                case .verdict: verdictBeat
                case .share:   shareBeat
                case .hook:    hookBeat
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.contentBottom)
        }
        .sheet(item: sharePayloadBinding) { payload in
            ActivityView(items: [payload.image])
        }
    }

    // MARK: - Beat 1 — verdict

    private var verdictBeat: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            eyebrow("CHALLENGE COMPLETE", color: FudoColor.accent)
            senseiWithBurst
                .padding(.top, 10)
            Text("Challenge complete.")
                .fudoFont(.title(26, weight: .heavy))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 14)
            Text(viewModel.verdictLine)
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 4)
            if let missed = viewModel.missedLine {
                Text(missed)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 2)
            }
            ovrBlock
                .padding(.top, 22)
            Spacer(minLength: 20)
            primaryCTA("Continue") { viewModel.advance() }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96)
        .task { await playVerdict() }
    }

    private var senseiWithBurst: some View {
        ZStack {
            SenseiAssetProvider.image(for: replayRank)
                .resizable()
                .scaledToFit()
                .frame(height: CompletionMetrics.senseiHeight)
                .id(replayRank)                       // rank change → crossfade
                .transition(.opacity)
        }
        .frame(height: CompletionMetrics.senseiHeight)
        .overlay {
            ParticleBurstView(colors: [FudoColor.celebrationGold, FudoColor.accent],
                              particleCount: ParticleBurstMetrics.dayCompleteCount,
                              distance: 100...150,
                              particleSize: 3...6,
                              startDistance: 14,
                              animation: AppAnimation.slow)
                .id(burstTrigger)
        }
        .accessibilityLabel("\(summary.endRank.displayName) sensei")
    }

    /// The OVR evolution: caption + the counting hero, the start noted below, and a
    /// gain badge that lands when the count settles.
    private var ovrBlock: some View {
        VStack(spacing: 2) {
            Text("OVR")
                .fudoFont(.caption(13))
                .kerning(4)
                .foregroundStyle(FudoColor.textSecondary)
            Text("\(displayedCount)")
                .fudoFont(.ovr(72))
                .foregroundStyle(FudoColor.textPrimary)
            Text("from \(summary.startOVR)")
                .fudoFont(.caption(12))
                .foregroundStyle(FudoColor.textSecondary)
                .opacity(summary.ovrGain == 0 ? 0 : 1)
            gainBadge
                .opacity(showGain ? 1 : 0)
                .padding(.top, 8)
        }
    }

    private var gainBadge: some View {
        let up = summary.ovrGain >= 0
        return HStack(spacing: 4) {
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .fudoFont(.stat(13))
            Text(viewModel.gainBadge)
                .fudoFont(.stat(17, weight: .heavy))
        }
        .foregroundStyle(up ? FudoColor.positive : FudoColor.negative)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(FudoColor.bgCard)
            .overlay(Capsule().strokeBorder(FudoColor.border, lineWidth: 1)))
    }

    // MARK: - Beat 2 — share

    private var shareBeat: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                eyebrow("SHARE YOUR RUN", color: FudoColor.accent)
                Text("Post the number.")
                    .fudoFont(.title(24, weight: .heavy))
                    .foregroundStyle(FudoColor.textPrimary)
            }
            .padding(.top, 12)

            cardPreview
                .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                shareButton
                secondaryTextButton("Next") { viewModel.advance() }
            }
        }
    }

    private var cardPreview: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, geo.size.height * 9 / 16)
            let scale = width / ShareCardView.canvas.width
            ShareCardView(data: viewModel.shareData, variant: .challengeEnd)
                .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
                .scaleEffect(scale)
                .frame(width: width, height: width * 16 / 9)
                .clipShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(FudoColor.border, lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var shareButton: some View {
        Button { viewModel.export() } label: {
            HStack(spacing: 8) {
                if viewModel.exportState == .rendering {
                    ProgressView().tint(FudoColor.textPrimary)
                } else {
                    Image(systemName: viewModel.exportState == .failed
                          ? "arrow.clockwise" : "square.and.arrow.up")
                        .fudoFont(.headline(16, weight: .semibold))
                }
                Text(viewModel.shareButtonLabel)
                    .fudoFont(.headline(17))
            }
            .foregroundStyle(FudoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: FudoSpacing.ctaHeight)
            .background(Capsule().fill(FudoColor.accent))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.exportState == .rendering)
        .animation(AppAnimation.standard, value: viewModel.exportState)
    }

    // MARK: - Beat 3 — the next hook

    private var hookBeat: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            SenseiAssetProvider.image(for: summary.endRank)
                .resizable()
                .scaledToFit()
                .frame(height: CompletionMetrics.hookSenseiHeight)
                .accessibilityHidden(true)
            Text(viewModel.hookLine)
                .fudoFont(.title(26, weight: .heavy))
                .foregroundStyle(FudoColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 12)
            Text("The rank is yours. The next one isn't — yet.")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 24)
            Spacer(minLength: 24)
            hookCTAs
        }
    }

    private var hookCTAs: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.medium()
                viewModel.chooseNext(onLaunch)
            } label: {
                ctaLabel(title: "Next challenge", subtitle: viewModel.superiorPresetTitle,
                         filled: true)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                viewModel.chooseRestart(onLaunch)
            } label: {
                ctaLabel(title: "Restart harder", subtitle: viewModel.restartSubtitle,
                         filled: false)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                onClose()
            } label: {
                Text("Maybe later")
                    .fudoFont(.headline(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private func ctaLabel(title: String, subtitle: String?, filled: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .fudoFont(.headline(17))
                .foregroundStyle(FudoColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .fudoFont(.caption(12))
                    .foregroundStyle(filled ? FudoColor.textPrimary.opacity(0.8) : FudoColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: FudoSpacing.ctaHeight)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(filled ? FudoColor.accent : FudoColor.bgCard)
        }
        .overlay {
            Capsule().strokeBorder(filled ? Color.clear : FudoColor.border, lineWidth: 1)
        }
    }

    // MARK: - Shared pieces

    private func eyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .fudoFont(.label(14, weight: .heavy))
            .kerning(4)
            .foregroundStyle(color)
    }

    private func primaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .fudoFont(.headline(17))
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background(Capsule().fill(FudoColor.accent))
        }
        .buttonStyle(.plain)
    }

    private func secondaryTextButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .fudoFont(.headline(16))
                .foregroundStyle(FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    /// Faint gold + vermillon celebration halo — the milestone light.
    private var glow: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accentDeep.opacity(0.40), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 320)
            RadialGradient(colors: [FudoColor.celebrationGold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.40), startRadius: 10, endRadius: 240)
        }
        .blur(radius: 30)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var sharePayloadBinding: Binding<CompletionSharePayload?> {
        Binding(get: { viewModel.sharePayload }, set: { viewModel.sharePayload = $0 })
    }

    // MARK: - Verdict animation

    private func playVerdict() async {
        guard !appeared else { return }
        withAnimation(AppAnimation.slow) { appeared = true }
        burstTrigger += 1
        async let count: Void = runCount()
        async let replay: Void = runReplay()
        _ = await (count, replay)
    }

    private func runCount() async {
        let from = summary.startOVR, to = summary.endOVR
        guard to != from else {
            withAnimation(AppAnimation.standard) { showGain = true }
            return
        }
        let steps = abs(to - from)
        let dir = to > from ? 1 : -1
        let per = min(0.05, 1.1 / Double(steps))
        for _ in 0..<steps {
            try? await Task.sleep(for: .seconds(per))
            if Task.isCancelled { return }
            displayedCount += dir
        }
        displayedCount = to
        Haptics.success()
        withAnimation(AppAnimation.standard) { showGain = true }
    }

    private func runReplay() async {
        guard summary.gainedRank else { return }
        var rank = summary.startRank
        while rank.rawValue < summary.endRank.rawValue {
            try? await Task.sleep(for: .seconds(0.55))
            if Task.isCancelled { return }
            guard let next = Rank(rawValue: rank.rawValue + 1) else { break }
            rank = next
            withAnimation(AppAnimation.standard) { replayRank = rank }
            Haptics.light()
        }
    }
}

/// Cover-specific sizing — no magic numbers in the view (CLAUDE.md).
private enum CompletionMetrics {
    static let senseiHeight: CGFloat = 232
    static let hookSenseiHeight: CGFloat = 180
}
