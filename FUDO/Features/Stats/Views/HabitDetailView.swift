import SwiftUI
import SwiftData

/// One habit, in depth (frame 05b) — PUSH, tab bar hidden (prd/12 §5). Back + a title
/// carrying the habit's SF Symbol and name. The 7d/30d/challenge picker repeats at the
/// top, its selection inherited from the Stats tab at push, then editable locally.
/// Header tiles · completion graph · step-by-step timeline · one line of local advice.
struct HabitDetailView: View {
    @State private var viewModel: HabitDetailViewModel
    @Query private var rules: [TaskRule]

    init(store: GameStore, ruleID: UUID, initialPeriod: StatsPeriod) {
        _viewModel = State(initialValue: HabitDetailViewModel(store: store, ruleID: ruleID,
                                                              initialPeriod: initialPeriod))
    }

    private var rule: TaskRule? { rules.first { $0.id == viewModel.ruleID } }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let rule, let challenge = rule.challenge {
                content(rule: rule, detail: viewModel.detail(rule: rule, challenge: challenge))
            } else {
                unavailable
            }
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
        @Bindable var viewModel = viewModel
        return ScrollView(showsIndicators: false) {
            VStack(spacing: FudoSpacing.sectionGap) {
                StatsPeriodPicker(period: $viewModel.period)

                HabitTilesRow(completionPercent: detail.completionPercent,
                              streak: detail.streak,
                              totalChecks: detail.totalChecks)

                HabitBarChart(bars: detail.bars, mode: detail.barMode, trend: detail.trend)

                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("STEP BY STEP")
                    HabitTimelineView(entries: detail.timeline)
                }

                StatsAdviceCard(text: detail.advice)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, FudoSpacing.sectionGap)
            .animation(AppAnimation.standard, value: viewModel.period)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .fudoFont(.label(12))
            .kerning(1.5)
            .foregroundStyle(FudoColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
