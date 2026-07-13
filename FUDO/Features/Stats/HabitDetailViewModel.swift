import Foundation
import Observation

/// The Habit-detail view model. Owns its own `period` (seeded from the tab's selection
/// at push, then free to change locally without affecting the tab). Read-only over the
/// store; the maths lives in `StatsAggregator`.
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
            .detail(for: rule, period: period)
    }
}
