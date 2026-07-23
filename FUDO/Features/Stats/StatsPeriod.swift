import Foundation

/// The stats window. Selected on the Stats tab (state), inherited by Habit detail
/// at push time. Labels are the segmented-control captions (uppercased already).
enum StatsPeriod: String, CaseIterable, Hashable {
    case week, month, challenge

    var label: String {
        switch self {
        case .week:      "7 DAYS"
        case .month:     "30 DAYS"
        case .challenge: "CHALLENGE"
        }
    }

    /// `stats_period_changed.period` (plan §1.8) — stable, not the UI caption.
    var analyticsValue: String {
        switch self {
        case .week:      "7d"
        case .month:     "30d"
        case .challenge: "challenge"
        }
    }

    /// Trailing calendar days counted back from today (inclusive). nil = the whole run.
    var trailingDays: Int? {
        switch self {
        case .week:      7
        case .month:     30
        case .challenge: nil
        }
    }
}

/// Push route to a single habit's detail. Carries the period so the detail screen
/// inherits the tab's selection (prd/12 §5). Hashable → NavigationPath value.
struct HabitDetailRoute: Hashable {
    let ruleID: UUID
    let period: StatsPeriod
}
