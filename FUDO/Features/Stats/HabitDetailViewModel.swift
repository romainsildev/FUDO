import Foundation
import Observation

/// The Habit-detail view model. The screen reads over the WHOLE run since the FINAL
/// redesign (2026-07-23) — the challenge map shows every day, so the pushed period is
/// kept only for route compatibility and the aggregation is pinned to `.challenge`.
/// Read-only over the store; the maths lives in `StatsAggregator`.
@MainActor
@Observable
final class HabitDetailViewModel {
    var period: StatsPeriod
    let ruleID: UUID

    private let store: GameStore

    init(store: GameStore, ruleID: UUID, initialPeriod: StatsPeriod) {
        self.store = store
        self.ruleID = ruleID
        self.period = initialPeriod
    }

    func detail(rule: TaskRule, challenge: Challenge) -> HabitDetail {
        StatsAggregator(challenge: challenge, calendar: store.displayCalendar, today: store.effectiveToday)
            .detail(for: rule, period: .challenge)
    }
}
