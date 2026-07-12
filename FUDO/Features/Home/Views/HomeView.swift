import SwiftUI

/// Collapsing-hero interpolation constants (2026-07-12 polish pass) — tune here,
/// never inline. All values drive DIRECT scroll interpolation (no animations),
/// so the collapse tracks the finger at 60 fps and reverses for free.
private enum HomeHeroMetrics {
    /// Scroll distance over which the hero fully condenses into the strip.
    /// Must stay well under the available scroll range (~150-250 pt with 5 cards
    /// on a tall iPhone) or the collapse never completes — device bug 2026-07-12.
    static let collapseDistance: CGFloat = 150
    /// Fraction of the collapse at which the compact strip starts fading in.
    static let stripAppearStart: CGFloat = 0.45
    static let stripHeight: CGFloat = 44
    static let heroMinScale: CGFloat = 0.86
    static let miniRingSize: CGFloat = 22
    static let miniRingWidth: CGFloat = 3
}

/// Home ("Today") — the core action screen. Answers in one second: where am I
/// today, what's left to do. Three states, never empty: in-progress (frame 01),
/// day complete (01c), no active challenge (01b). The top header is PINNED; the
/// hero collapses into a compact strip as the checklist scrolls.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel
    @State private var scrollOffset: CGFloat = 0

    init(store: GameStore) {
        _viewModel = State(initialValue: HomeViewModel(store: store))
    }

    /// 0 = hero fully expanded · 1 = fully collapsed.
    private var heroT: CGFloat {
        min(1, max(0, scrollOffset / HomeHeroMetrics.collapseDistance))
    }

    /// Strip fade-in, riding the tail of the hero collapse.
    private var stripT: CGFloat {
        let start = HomeHeroMetrics.stripAppearStart
        return min(1, max(0, (heroT - start) / (1 - start)))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            header
                .padding(.horizontal, FudoSpacing.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(FudoColor.bgPrimary)

            if viewModel.screenState == .noChallenge {
                noChallengeContent
            } else {
                activeContent
            }
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .fudoSheet(item: $viewModel.presentedSheet) { sheet in
            if sheet == .flame {
                FlameSheetView(viewModel: viewModel)
            }
        }
        .fudoCover(item: $viewModel.presentedCover) { cover in
            if cover == .challengeSetup {
                challengeSetupStub
            }
        }
        .task { await viewModel.watchRolloverWhileForeground() }
    }

    // MARK: - Active challenge (frames 01 / 01c) — collapsing hero

    private var activeContent: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.showsIncompleteBanner, let summary = viewModel.incompleteRollover {
                        incompleteBanner(summary)
                            .padding(.top, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    senseiAndOVRBlock
                        .scaleEffect(1 - (1 - HomeHeroMetrics.heroMinScale) * heroT, anchor: .top)
                        .opacity(1 - heroT)

                    if viewModel.screenState == .dayComplete {
                        completionBlock
                            .padding(.top, 14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    protocolSection
                        .padding(.top, FudoSpacing.sectionGap)
                }
                .padding(.horizontal, FudoSpacing.screenMargin)
                .padding(.bottom, 100)   // clear of the floating tab pill
                .animation(AppAnimation.standard, value: viewModel.screenState)
                .animation(AppAnimation.standard, value: viewModel.showsIncompleteBanner)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: HomeScrollOffsetKey.self,
                                               value: -geo.frame(in: .named("homeScroll")).minY)
                    }
                }
            }
            .coordinateSpace(name: "homeScroll")
            .modifier(HomeScrollOffsetReader { scrollOffset = $0 })

            compactStrip
                .opacity(stripT)
                .offset(y: (1 - stripT) * -8)
                .allowsHitTesting(stripT > 0.6)
        }
    }

    /// Condensed hero pinned under the header once the full hero scrolls away:
    /// head + "61 · ASCETIC" + mini day ring, one 44 pt glass row → Progress.
    private var compactStrip: some View {
        Button(action: goToProgress) {
            HStack(spacing: 10) {
                SenseiAvatarView(rank: viewModel.rank, diameter: 28)
                Text("\(viewModel.displayedOVR)")
                    .font(.system(size: 17, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FudoColor.textPrimary)
                Text("· \(viewModel.rank.displayName)")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.accent)
                Spacer(minLength: 8)
                Text("\(viewModel.checkedCount)/\(viewModel.totalCount)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(FudoColor.textSecondary)
                miniDayRing
            }
            .padding(.horizontal, 14)
            .frame(height: HomeHeroMetrics.stripHeight)
            .fudoGlassCapsule()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .accessibilityLabel("OVR \(viewModel.displayedOVR), \(viewModel.rank.displayName), \(viewModel.checkedCount) of \(viewModel.totalCount) done — open Progress")
    }

    private var miniDayRing: some View {
        ZStack {
            Circle()
                .stroke(FudoColor.border, lineWidth: HomeHeroMetrics.miniRingWidth)
            Circle()
                .trim(from: 0, to: viewModel.dayProgress)
                .stroke(FudoColor.accent,
                        style: StrokeStyle(lineWidth: HomeHeroMetrics.miniRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: HomeHeroMetrics.miniRingSize, height: HomeHeroMetrics.miniRingSize)
        .animation(AppAnimation.standard, value: viewModel.dayProgress)
    }

    /// Sensei stage + giant OVR + rank line. Tappable as one block → Progress
    /// (double affordance with the header avatar, D2).
    private var senseiAndOVRBlock: some View {
        VStack(spacing: 0) {
            SenseiStageView(rank: viewModel.rank,
                            mood: viewModel.isYesterdayIncomplete ? .slumped : .focused,
                            progress: viewModel.dayProgress,
                            showsRingProgress: true,
                            pulseTrigger: viewModel.checkPulseTrigger,
                            celebrationTrigger: viewModel.celebrationTrigger)
                .padding(.top, 4)

            Text("\(viewModel.displayedOVR)")
                .font(FudoFont.ovr(84))
                .foregroundStyle(FudoColor.textPrimary)

            rankLine
        }
        .contentShape(Rectangle())
        .onTapGesture { goToProgress() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("OVR \(viewModel.displayedOVR), \(viewModel.rank.displayName) — open Progress")
    }

    private var rankLine: some View {
        HStack(spacing: 6) {
            Text(viewModel.rank.displayName)
                .font(.system(size: 14, weight: .bold))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
            if let delta = viewModel.ovrDeltaToday {
                Text("•")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FudoColor.textSecondary)
                deltaBadge(delta)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(AppAnimation.standard, value: viewModel.ovrDeltaToday != nil)
    }

    /// The ARROW carries the green/red; everything vermillon stays vermillon (2026-07-11).
    private func deltaBadge(_ delta: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 9, weight: .bold))
            Text(String(format: "%+.1f today", delta))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(delta >= 0 ? FudoColor.positive : FudoColor.negative)
    }

    /// Factual, one line, dismissible (rollover session). The number is the
    /// penalty the closure took; the negative color rides the number only.
    private func incompleteBanner(_ summary: IncompleteRolloverSummary) -> some View {
        HStack(spacing: 12) {
            (
                Text(summary.dayCount == 1
                     ? "Yesterday: incomplete. "
                     : "\(summary.dayCount) days incomplete. ")
                    .foregroundStyle(FudoColor.textPrimary)
                + Text(String(format: "OVR -%.1f.", summary.ovrDrop))
                    .foregroundStyle(FudoColor.negative)
            )
            .font(.system(size: 15, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button {
                withAnimation(AppAnimation.standard) { viewModel.dismissIncompleteBanner() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, FudoSpacing.cardPadding)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var completionBlock: some View {
        VStack(spacing: 8) {
            Text(viewModel.completionMessage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FudoColor.textPrimary)
            // Stub — wired to the share card in the share session.
            Button {} label: {
                HStack(spacing: 4) {
                    Text("Share my day")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(FudoColor.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var protocolSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("TODAY'S PROTOCOL")
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Spacer()
                Text("\(viewModel.checkedCount) / \(viewModel.totalCount)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(FudoColor.accent)
            }
            VStack(spacing: 10) {
                ForEach(viewModel.items) { item in
                    ChecklistRowView(title: item.rule.title,
                                     iconName: item.rule.iconName,
                                     isChecked: item.isChecked,
                                     onHoldConfirmed: { viewModel.confirmCheck(item) },
                                     onUncheckConfirmed: { viewModel.uncheck(item) })
                }
            }
            .animation(AppAnimation.standard, value: viewModel.items)
        }
    }

    // MARK: - No active challenge (frame 01b — never an empty screen)

    private var noChallengeContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            VStack(spacing: 0) {
                SenseiStageView(rank: viewModel.rank,
                                mood: .resting,
                                progress: 0,
                                showsRingProgress: false,
                                pulseTrigger: 0,
                                celebrationTrigger: 0)
                Text("\(viewModel.displayedOVR)")
                    .font(FudoFont.ovr(84))
                    .foregroundStyle(FudoColor.textPrimary)
                rankLine
            }
            .contentShape(Rectangle())
            .onTapGesture { goToProgress() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

            VStack(spacing: 8) {
                Text("Your rank awaits.")
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                Text("The dojo doesn't close. Start again.")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .padding(.top, 28)

            Spacer(minLength: 20)

            Button {
                Haptics.medium()
                viewModel.presentedCover = .challengeSetup
            } label: {
                Text("Start a new challenge")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(FudoColor.accent) }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 90)   // clear of the floating tab pill
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
    }

    // MARK: - Shared pieces

    private var header: some View {
        HomeHeaderView(rank: viewModel.rank,
                       dayPillLabel: viewModel.dayPillLabel,
                       streak: viewModel.streak,
                       streakIsAlive: viewModel.streakIsAlive,
                       onAvatarTap: goToProgress,
                       onFlameTap: { viewModel.presentedSheet = .flame })
    }

    /// Cover stub until the real ChallengeSetup flow ships — the temporary close
    /// button is the only exit (real flow owns its own exits, covers never swipe).
    private var challengeSetupStub: some View {
        ZStack(alignment: .topTrailing) {
            ChallengeSetupPlaceholderView()
            Button {
                viewModel.presentedCover = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
    }

    private func goToProgress() {
        appState.selectedTab = .progress
    }
}

/// Scroll offset of the Home checklist scroll view, in its own coordinate space.
private struct HomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Offset reading, two paths: iOS 18+ uses the native `onScrollGeometryChange`
/// (reliable during live scroll on iOS 26 — the PreferenceKey pattern proved
/// flaky there, device bug 2026-07-12); iOS 17 falls back to the GeometryReader
/// preference emitted by the scroll content.
private struct HomeScrollOffsetReader: ViewModifier {
    let onChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                onChange(offset)
            }
        } else {
            content.onPreferenceChange(HomeScrollOffsetKey.self) { onChange($0) }
        }
    }
}
