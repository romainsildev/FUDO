import SwiftUI
import SwiftData

/// The Stats tab (frame 05) — the habits screen. Frontier with Progress: Progress owns
/// the challenge and the rank, Stats owns the habits (execution, trends, advice). All
/// numbers are aggregated locally from `DayLog.checks`; nothing new is captured.
///
/// Three states, never empty:
///  • active challenge → the live stats;
///  • no active challenge but a past run → that run's stats, blurred, under a "go again"
///    CTA (session decision 2026-07-13 — the last run stays visible as motivation);
///  • never ran → a calm CTA.
struct StatsView: View {
    @State private var viewModel: StatsViewModel
    @State private var setupCover: FudoCover?
    @Query(sort: \Challenge.createdAt, order: .reverse) private var challenges: [Challenge]

    private let store: GameStore

    init(store: GameStore) {
        self.store = store
        _viewModel = State(initialValue: StatsViewModel(store: store))
    }

    private var activeChallenge: Challenge? { store.activeChallenge }
    private var lastRun: Challenge? { challenges.first { $0.status != .active } }

    var body: some View {
        content
            .background(FudoColor.bgPrimary.ignoresSafeArea())
            .navigationDestination(for: HabitDetailRoute.self) { route in
                HabitDetailView(store: store, ruleID: route.ruleID, initialPeriod: route.period)
            }
            .fudoCover(item: $setupCover) { cover in
                if cover == .challengeSetup {
                    ChallengeSetupStandaloneView(store: store) { setupCover = nil }
                }
            }
            .onAppear { Analytics.track(AnalyticsEvent.statsViewed) }
            .onChange(of: viewModel.period) { _, newPeriod in
                Analytics.track(AnalyticsEvent.statsPeriodChanged, ["period": newPeriod.analyticsValue])
            }
    }

    @ViewBuilder
    private var content: some View {
        if let active = activeChallenge {
            statsBody(for: active)
        } else if let last = lastRun {
            lockedLastRun(last)
        } else {
            emptyState
        }
    }

    // MARK: - Live stats

    private func statsBody(for challenge: Challenge) -> some View {
        @Bindable var viewModel = viewModel
        // Stats FINAL (2026-07-23): the segmented control is gone — the period lives
        // in a header pill menu; a checks-per-day graph sits under the summary.
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FudoSpacing.sectionGap) {
                HStack(alignment: .center) {
                    Text("Stats")
                        .fudoFont(.title(34))
                        .foregroundStyle(FudoColor.textPrimary)
                    Spacer()
                    StatsPeriodMenu(period: $viewModel.period)
                }
                .padding(.top, 4)

                PeriodSummaryCard(summary: viewModel.summary(for: challenge),
                                  delta: viewModel.completionDelta(for: challenge),
                                  period: viewModel.period)

                ChecksPerDayCard(days: viewModel.checksPerDay(for: challenge),
                                 maxChecks: max(challenge.activeRules.count, 1))

                TopFlopRow(topFlop: viewModel.topFlop(for: challenge))

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("BY HABIT")
                    VStack(spacing: 10) {
                        ForEach(viewModel.habitStats(for: challenge)) { habit in
                            HabitStatRow(habit: habit, period: viewModel.period)
                        }
                    }
                }

                StatsAdviceCard(text: viewModel.overallAdvice(for: challenge))
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.contentBottom)
            .animation(AppAnimation.standard, value: viewModel.period)
        }
    }

    // MARK: - Locked (past run behind a CTA)

    private func lockedLastRun(_ last: Challenge) -> some View {
        ZStack {
            statsBody(for: last)
                .disabled(true)
                .blur(radius: 7)
                .allowsHitTesting(false)

            FudoColor.bgPrimary.opacity(0.55).ignoresSafeArea()

            lastRunCTACard(last)
                .padding(.horizontal, FudoSpacing.screenMargin)
        }
    }

    private func lastRunCTACard(_ last: Challenge) -> some View {
        let completion = StatsAggregator(challenge: last, calendar: store.displayCalendar,
                                         today: store.effectiveToday)
            .summary(.challenge).completionPercent
        let from = OVREngine.displayedOVR(last.startOVR)
        let to = OVREngine.displayedOVR(last.endOVR ?? last.startOVR)

        return VStack(spacing: 14) {
            Text("You showed up last run.")
                .fudoFont(.title(24))
                .foregroundStyle(FudoColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("\(completion)% completion · OVR \(from) → \(to)")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)

            Text("The dojo doesn't close. Go earn the next one.")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            startButton
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    // MARK: - Empty (never ran)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("Stats")
                .fudoFont(.title(34))
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            Spacer(minLength: 40)

            VStack(spacing: 8) {
                Text("Your habits, measured.")
                    .fudoFont(.title())
                    .foregroundStyle(FudoColor.textPrimary)
                Text("Start a challenge and this fills with your real numbers — completion, streaks, weak spots.")
                    .fudoFont(.body())
                    .foregroundStyle(FudoColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 40)

            startButton
                .padding(.bottom, FudoSpacing.contentBottom)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
    }

    // MARK: - Shared

    private var startButton: some View {
        Button {
            Haptics.medium()
            setupCover = .challengeSetup
        } label: {
            Text("Start a new challenge")
                .fudoFont(.headline(17))
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .fudoFont(.label(12))
            .kerning(1.5)
            .foregroundStyle(FudoColor.textSecondary)
    }
}

#if DEBUG
#Preview("Stats — live") {
    if let store = AppPreviewFactory.store, let container = AppPreviewFactory.container {
        NavigationStack { StatsView(store: store) }
            .modelContainer(container)
            .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif
