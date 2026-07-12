import Foundation
import SwiftData

/// One log per challenge day. Created at rollover (or first access of the day);
/// (challenge, date) uniqueness enforced by GameStore. The gain pool is frozen at
/// creation — the structural anti-farming cap for that day.
@Model
final class DayLog {
    @Attribute(.unique) var id: UUID
    var date: Date             // startOfDay (effective gameplay day)
    var dayNumber: Int         // 1-based (day X / Y)
    var checks: [TaskCheck]    // checked tasks with exact time + exact granted delta
    var dailyGainPool: Double  // (99 − ovrAtDayStart) × dailyRate, frozen at creation
    var isComplete: Bool       // 100 % of active rules checked — frozen at closure
    var isClosed: Bool         // rollover done (past grace period)
    var ovrDelta: Double       // net applied this day = Σ check deltas − penalty — frozen at closure
    var challenge: Challenge?

    init(id: UUID = UUID(), date: Date, dayNumber: Int, dailyGainPool: Double) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
        self.checks = []
        self.dailyGainPool = dailyGainPool
        self.isComplete = false
        self.isClosed = false
        self.ovrDelta = 0
    }
}

extension DayLog {
    /// Sum of the exact deltas granted so far today.
    var checksTotal: Double {
        checks.reduce(0) { $0 + $1.ovrDelta }
    }

    func isChecked(_ rule: TaskRule) -> Bool {
        checks.contains { $0.ruleID == rule.id }
    }
}
