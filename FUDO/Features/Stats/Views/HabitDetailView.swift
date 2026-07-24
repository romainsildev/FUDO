import SwiftUI
import SwiftData

/// One habit, in depth (Habit FINAL, 2026-07-23) — PUSH, tab bar hidden (prd/12 §5).
/// Back + a title carrying the habit's SF Symbol and name. The period picker is gone:
/// this screen now reads over the whole run. Header tiles (challenge scope) · the
/// challenge map (every day, one grid) · "when you check" (hour-of-day histogram).
struct HabitDetailView: View {
    @State private var viewModel: HabitDetailViewModel
    @Query private var rules: [TaskRule]

    init(store: GameStore, ruleID: UUID, initialPeriod: StatsPeriod) {
        _viewModel = State(initialValue: HabitDetailViewModel(store: store, ruleID: ruleID,
                                                              initialPeriod: initialPeriod))
    }

    private var rule: TaskRule? { rules.first { $0.id == viewModel.ruleID } }

    var body: some View {
        Group {
            if let rule, let challenge = rule.challenge {
                content(rule: rule, detail: viewModel.detail(rule: rule, challenge: challenge))
            } else {
                unavailable
            }
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Anonymous slug — the user-typed title never leaves the device (plan §1.8).
            if let rule {
                Analytics.track(AnalyticsEvent.habitDetailViewed,
                                ["habit": AnalyticsHabit.slug(iconName: rule.iconName,
                                                              index: rule.sortOrder)])
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    if let rule {
                        Image(systemName: rule.iconName)
                            .fudoFont(.headline(14))
                            .foregroundStyle(FudoColor.accent)
                    }
                    Text(rule?.title ?? "Habit")
                        .fudoFont(.headline(17))
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
        }
        .fudoHidesTabBar()
    }

    private func content(rule: TaskRule, detail: HabitDetail) -> some View {
        let dayNo = currentDayNumber(in: detail.calendarDays)
        let duration = detail.calendarDays.count
        return ScrollView(showsIndicators: false) {
            VStack(spacing: FudoSpacing.sectionGap) {
                HabitHeroCard(completionPercent: detail.completionPercent,
                              dayNumber: dayNo,
                              durationDays: duration,
                              streak: detail.streak)

                HabitBoardCard(days: detail.calendarDays,
                               dayNumber: dayNo,
                               durationDays: duration)

                if let peakLine = detail.peakLine {
                    WhenYouCheckCard(buckets: detail.hourBuckets, peakLine: peakLine)
                }

                ending(dayNumber: dayNo)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, FudoSpacing.sectionGap)
        }
    }

    /// The dry sign-off under the board (Habit FINAL v3-B3): a fact, not a pep-talk.
    private func ending(dayNumber: Int) -> some View {
        Text("\(dayNumber) day\(dayNumber == 1 ? "" : "s") on the board. Keep walking.")
            .fudoFont(.body(12))
            .foregroundStyle(FudoColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Today's day number for the map header — falls back to the last played day
    /// (looking at a finished run) and then to 1.
    private func currentDayNumber(in days: [CalendarDay]) -> Int {
        days.first(where: \.isToday)?.dayNumber
            ?? days.last(where: { $0.state != .future })?.dayNumber
            ?? 1
    }

    private var unavailable: some View {
        VStack(spacing: 8) {
            Text("Habit unavailable")
                .fudoFont(.title())
                .foregroundStyle(FudoColor.textPrimary)
            Text("This habit is no longer part of an active challenge.")
                .fudoFont(.body())
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Habit detail — hero + board") {
    if let store = AppPreviewFactory.store, let container = AppPreviewFactory.container,
       let ruleID = AppPreviewFactory.sampleRuleID {
        NavigationStack {
            HabitDetailView(store: store, ruleID: ruleID, initialPeriod: .challenge)
        }
        .modelContainer(container)
        .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif
