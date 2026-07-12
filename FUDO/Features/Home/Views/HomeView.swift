import SwiftUI

/// Home ("Today") — the core action screen. Answers in one second: where am I
/// today, what's left to do. Three states, never empty: in-progress (frame 01),
/// day complete (01c), no active challenge (01b).
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel

    init(store: GameStore) {
        _viewModel = State(initialValue: HomeViewModel(store: store))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            if viewModel.screenState == .noChallenge {
                noChallengeContent
            } else {
                activeContent
            }
        }
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
    }

    // MARK: - Active challenge (frames 01 / 01c)

    private var activeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                senseiAndOVRBlock

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
        }
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
            header
                .padding(.top, 8)

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
