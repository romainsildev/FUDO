import SwiftUI

/// Collapsing-hero interpolation constants (2026-07-12 polish pass) — tune here,
/// never inline. All values drive DIRECT scroll interpolation (no animations),
/// so the collapse tracks the finger at 60 fps and reverses for free.
private enum HomeHeroMetrics {
    /// Scroll distance over which the hero fully condenses into the card.
    /// Must stay well under the available scroll range (~150-250 pt with 5 cards
    /// on a tall iPhone) or the collapse never completes — device bug 2026-07-12.
    static let collapseDistance: CGFloat = 150
    /// Fraction of the collapse at which the collapsed card starts fading in.
    static let cardAppearStart: CGFloat = 0.45
    /// Collapsed hero card (frame 01-collapsed) — one horizontal card ~112 pt.
    static let collapsedHeight: CGFloat = 112
    static let collapsedAppearScale: CGFloat = 0.96
    static let heroMinScale: CGFloat = 0.86
    /// Mini sensei in its small ring arc, left side of the collapsed card.
    static let miniSenseiSize: CGFloat = 62
    static let miniRingWidth: CGFloat = 3.5
    static let rankBarHeight: CGFloat = 3
    /// Expanded hero (frame 01 v2) — sensei centered in the ring arc, compact stage.
    static let expandedStageHeight: CGFloat = 258
    static let expandedRingDiameter: CGFloat = 248
    static let expandedSenseiHeight: CGFloat = 294
}

/// Home ("Today") — the core action screen. Answers in one second: where am I
/// today, what's left to do. Three states, never empty: in-progress (frame 01),
/// day complete (01c), no active challenge (01b). The top header is PINNED; the
/// hero collapses into a compact strip as the checklist scrolls.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel
    @State private var scrollOffset: CGFloat = 0
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
        _viewModel = State(initialValue: HomeViewModel(store: store))
    }

    /// 0 = hero fully expanded · 1 = fully collapsed.
    private var heroT: CGFloat {
        min(1, max(0, scrollOffset / HomeHeroMetrics.collapseDistance))
    }

    /// Collapsed-card fade-in, riding the tail of the hero collapse.
    private var cardT: CGFloat {
        let start = HomeHeroMetrics.cardAppearStart
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
                ChallengeSetupStandaloneView(store: store) {
                    viewModel.presentedCover = nil
                }
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
                .padding(.bottom, FudoSpacing.contentBottom)
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

            collapsedHeroCard
                .opacity(cardT)
                .scaleEffect(HomeHeroMetrics.collapsedAppearScale
                             + (1 - HomeHeroMetrics.collapsedAppearScale) * cardT,
                             anchor: .top)
                .allowsHitTesting(cardT > 0.6)
        }
    }

    /// Collapsed hero (frame 01-collapsed) pinned under the header once the full
    /// hero scrolls away: mini sensei in its day-ring arc + OVR + rank with the
    /// thin next-rank bar + today delta, one ~112 pt card → Progress.
    private var collapsedHeroCard: some View {
        Button(action: goToProgress) {
            HStack(spacing: 16) {
                miniSenseiRing
                Text("\(viewModel.displayedOVR)")
                    .fudoFont(.ovr(40))
                    .foregroundStyle(FudoColor.textPrimary)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(viewModel.rank.displayName)
                            .fudoFont(.label(13, weight: .heavy))
                            .kerning(1.5)
                            .foregroundStyle(FudoColor.accent)
                        Spacer(minLength: 8)
                        todayDelta(viewModel.ovrDeltaToday, fontSize: 13)
                    }
                    rankProgressBar
                    Text(viewModel.nextRankBarLabel)
                        .fudoFont(.stat(10, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(FudoColor.textSecondary)
                }
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            .frame(maxWidth: .infinity)
            .frame(height: HomeHeroMetrics.collapsedHeight)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
                    .strokeBorder(FudoColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .accessibilityLabel("OVR \(viewModel.displayedOVR), \(viewModel.rank.displayName), \(viewModel.nextRankBarLabel) — open Progress")
    }

    /// Mini sensei in a small ring arc — the arc mirrors today's progress,
    /// same signal as the big stage ring.
    private var miniSenseiRing: some View {
        ZStack {
            Circle()
                .fill(FudoColor.bgPrimary)
            SenseiAssetProvider.image(for: viewModel.rank)
                .resizable()
                .scaledToFit()
                .frame(height: HomeHeroMetrics.miniSenseiSize - 12)
                .frame(width: HomeHeroMetrics.miniSenseiSize,
                       height: HomeHeroMetrics.miniSenseiSize)
                .clipShape(Circle())
            Circle()
                .stroke(FudoColor.border, lineWidth: HomeHeroMetrics.miniRingWidth)
            Circle()
                .trim(from: 0, to: viewModel.dayProgress)
                .stroke(FudoColor.accent,
                        style: StrokeStyle(lineWidth: HomeHeroMetrics.miniRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: HomeHeroMetrics.miniSenseiSize, height: HomeHeroMetrics.miniSenseiSize)
        .animation(AppAnimation.standard, value: viewModel.dayProgress)
    }

    /// Thin bar inside the current rank band — full + "MAX RANK" at Sensei.
    private var rankProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FudoColor.border)
                Capsule()
                    .fill(FudoColor.accent)
                    .frame(width: max(HomeHeroMetrics.rankBarHeight,
                                      geo.size.width * viewModel.rankProgress))
            }
        }
        .frame(height: HomeHeroMetrics.rankBarHeight)
    }

    /// Sensei stage + stat line (frame 01 v2). Tappable as one block → Progress
    /// (double affordance with the header avatar, D2).
    private var senseiAndOVRBlock: some View {
        VStack(spacing: 10) {
            SenseiStageView(rank: viewModel.rank,
                            mood: viewModel.isYesterdayIncomplete ? .slumped : .focused,
                            progress: viewModel.dayProgress,
                            showsRingProgress: true,
                            pulseTrigger: viewModel.checkPulseTrigger,
                            celebrationTrigger: viewModel.celebrationTrigger,
                            stageHeight: HomeHeroMetrics.expandedStageHeight,
                            ringDiameter: HomeHeroMetrics.expandedRingDiameter,
                            senseiHeight: HomeHeroMetrics.expandedSenseiHeight,
                            centersSensei: true)
                .padding(.top, 4)

            heroStatLine
        }
        .contentShape(Rectangle())
        .onTapGesture { goToProgress() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("OVR \(viewModel.displayedOVR), \(viewModel.rank.displayName) — open Progress")
    }

    /// Single stat line under the stage (frame 01 v2): rank block (right-aligned)
    /// | vermillon divider | giant OVR — biggest number on screen | thin divider
    /// | today delta. The 7 dots / totals moved to the flame sheet.
    private var heroStatLine: some View {
        HStack(spacing: 16) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("RANK")
                    .fudoFont(.label(10, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Text(viewModel.rank.displayName)
                    .fudoFont(.label(16, weight: .heavy))
                    .kerning(1.2)
                    .foregroundStyle(FudoColor.accent)
                Text(viewModel.nextRankHint)
                    .fudoFont(.stat(10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(FudoColor.textSecondary)
            }

            Capsule()
                .fill(FudoColor.accent)
                .frame(width: 3, height: 44)

            Text("\(viewModel.displayedOVR)")
                .fudoFont(.ovr(60))
                .foregroundStyle(FudoColor.textPrimary)

            Capsule()
                .fill(FudoColor.border)
                .frame(width: 1, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY")
                    .fudoFont(.label(10, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                todayDelta(viewModel.ovrDeltaToday, fontSize: 15)
            }
        }
        .animation(AppAnimation.standard, value: viewModel.ovrDeltaToday != nil)
    }

    /// The ARROW carries the green/red (2026-07-11). Quiet dash when nothing
    /// moved yet today.
    @ViewBuilder
    private func todayDelta(_ delta: Double?, fontSize: CGFloat) -> some View {
        if let delta {
            HStack(spacing: 3) {
                Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .fudoFont(.stat(fontSize * 0.6))
                Text(String(format: "%+.1f", delta))
                    .fudoFont(.stat(fontSize))
            }
            .foregroundStyle(delta >= 0 ? FudoColor.positive : FudoColor.negative)
        } else {
            Text("—")
                .fudoFont(.stat(fontSize))
                .foregroundStyle(FudoColor.textSecondary)
        }
    }

    private var rankLine: some View {
        HStack(spacing: 6) {
            Text(viewModel.rank.displayName)
                .fudoFont(.label(14, weight: .bold))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
            if let delta = viewModel.ovrDeltaToday {
                Text("•")
                    .fudoFont(.label(12, weight: .bold))
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
                .fudoFont(.stat(9, weight: .bold))
            Text(String(format: "%+.1f today", delta))
                .fudoFont(.stat(13, weight: .semibold))
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
            .fudoFont(.body(15, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button {
                withAnimation(AppAnimation.standard) { viewModel.dismissIncompleteBanner() }
            } label: {
                Image(systemName: "xmark")
                    .fudoFont(.body(12, weight: .semibold))
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
                .fudoFont(.headline(17))
                .foregroundStyle(FudoColor.textPrimary)
            // Stub — wired to the share card in the share session.
            Button {} label: {
                HStack(spacing: 4) {
                    Text("Share my day")
                        .fudoFont(.headline(15))
                    Image(systemName: "chevron.right")
                        .fudoFont(.headline(11))
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
                    .fudoFont(.label(12))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                Spacer()
                Text("\(viewModel.checkedCount) / \(viewModel.totalCount)")
                    .fudoFont(.stat(13))
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

    /// Fixed-height blocks (340pt stage + giant OVR + copy + CTA) can exceed the
    /// space under the pinned header on smaller screens: a plain VStack then
    /// overflows BOTH ends and shoves the header into the status bar (device bug
    /// 2026-07-13). ScrollView + minHeight keeps the layout identical when it
    /// fits (spacers distribute) and scrolls instead of overflowing when not.
    private var noChallengeContent: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
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
                            .fudoFont(.ovr(84))
                            .foregroundStyle(FudoColor.textPrimary)
                        rankLine
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { goToProgress() }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)

                    VStack(spacing: 8) {
                        Text("Your rank awaits.")
                            .fudoFont(.title())
                            .foregroundStyle(FudoColor.textPrimary)
                        Text("The dojo doesn't close. Start again.")
                            .fudoFont(.body())
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                    .padding(.top, 28)

                    Spacer(minLength: 20)

                    Button {
                        Haptics.medium()
                        viewModel.presentedCover = .challengeSetup
                    } label: {
                        Text("Start a new challenge")
                            .fudoFont(.headline(17))
                            .foregroundStyle(FudoColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: FudoSpacing.ctaHeight)
                            .background { Capsule().fill(FudoColor.accent) }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, FudoSpacing.contentBottom)
                }
                .padding(.horizontal, FudoSpacing.screenMargin)
                .frame(minHeight: geo.size.height)
            }
        }
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

    private func goToProgress() {
        appState.selectedTab = .progress
    }
}

#if DEBUG
import SwiftData

/// Xcode canvas preview — ONE in-memory container on the shared FudoSchema
/// (SwiftData pitfall 2026-07-12), seeded with the standard debug dataset
/// (day 12, OVR 61, streak 4, 3/5 checked). Scroll the canvas in live mode
/// to see the collapsed card. Hand-tune `HomeHeroMetrics` against this.
@MainActor
private enum HomePreviewFactory {
    /// Retained for the whole preview process: mainContext does NOT keep its
    /// container alive — let it dealloc and SwiftData resets the context,
    /// destroying every fetched model ("Fatal Error in BackingData.swift",
    /// canvas crash 2026-07-15). Same reason FUDOApp stores its container.
    static let container: ModelContainer? = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let built = try ModelContainer(for: FudoSchema.schema, configurations: config)
            DebugSeed.seed(context: built.mainContext)
            return built
        } catch {
            return nil
        }
    }()

    // Built AFTER the seed — the seed replays through its own GameStore,
    // so a fresh store fetches the final player/challenge.
    static let store: GameStore? = container.map { GameStore(modelContext: $0.mainContext) }
}

#Preview("Home — day in progress") {
    if let store = HomePreviewFactory.store {
        HomeView(store: store)
            .environment(AppState())
            .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif

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
