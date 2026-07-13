import Foundation
import Observation

/// The Stats tab view model. Thin: it owns the selected `period` (state, inherited by
/// the pushed detail) and reads the store's clock; the maths lives in `StatsAggregator`.
/// Read-only over `GameStore` — never mutates, never touches `Date.now`.
@MainActor
@Observable
final class StatsViewModel {
    var period: StatsPeriod = .week

    private let store: GameStore
    init(store: GameStore) { self.store = store }

    private func aggregator(for challenge: Challenge) -> StatsAggregator {
        StatsAggregator(challenge: challenge, calendar: store.displayCalendar, today: store.effectiveToday)
    }

    func summary(for challenge: Challenge) -> PeriodSummary {
        aggregator(for: challenge).summary(period)
    }

    func topFlop(for challenge: Challenge) -> TopFlop? {
        aggregator(for: challenge).topFlop(period)
    }

    func habitStats(for challenge: Challenge) -> [HabitStat] {
        aggregator(for: challenge).habitStats(period)
    }

    func overallAdvice(for challenge: Challenge) -> String {
        aggregator(for: challenge).overallAdvice(period)
    }
}
