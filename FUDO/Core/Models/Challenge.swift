import Foundation
import SwiftData

/// One fixed-duration challenge. Invariant: a single `.active` at a time —
/// enforced by GameStore (no composite SwiftData constraint on iOS 17).
@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var preset: ChallengePreset
    var durationDays: Int
    var startDate: Date            // startOfDay of day 1
    var status: ChallengeStatus
    var reminderMinutes: Int       // daily reminder, minutes since midnight (7:00 AM = 420)
    var restDayWeekday: Int?       // D5 — schema only, no UI in MVP (1 = Sunday … 7 = Saturday)
    var startOVR: Double
    var endOVR: Double?            // frozen at completion/abandon
    var rulesLockedAfterDay: Int   // copied from GameConfig.rulesLockDay at creation, for audit
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TaskRule.challenge)
    var rules: [TaskRule]

    @Relationship(deleteRule: .cascade, inverse: \DayLog.challenge)
    var dayLogs: [DayLog]

    init(id: UUID = UUID(), preset: ChallengePreset, durationDays: Int, startDate: Date,
         status: ChallengeStatus = .active, reminderMinutes: Int, restDayWeekday: Int? = nil,
         startOVR: Double, rulesLockedAfterDay: Int = GameConfig.rulesLockDay, createdAt: Date = .now) {
        self.id = id
        self.preset = preset
        self.durationDays = durationDays
        self.startDate = startDate
        self.status = status
        self.reminderMinutes = reminderMinutes
        self.restDayWeekday = restDayWeekday
        self.startOVR = startOVR
        self.endOVR = nil
        self.rulesLockedAfterDay = rulesLockedAfterDay
        self.createdAt = createdAt
        self.rules = []
        self.dayLogs = []
    }
}

extension Challenge {
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays - 1, to: startDate) ?? startDate
    }

    /// 1-based "day X / Y", following the gameplay clock (grace period included):
    /// at 1:30 AM you are still living the previous day.
    func currentDayNumber(now: Date, calendar: Calendar = .current) -> Int {
        let effective = OVREngine.effectiveDay(now: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                           to: effective).day ?? 0
        return days + 1
    }

    func isRuleEditingLocked(now: Date, calendar: Calendar = .current) -> Bool {
        currentDayNumber(now: now, calendar: calendar) > rulesLockedAfterDay
    }

    /// Active rules in checklist order — the set a day must fully check to be complete.
    var activeRules: [TaskRule] {
        rules.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }
    }
}
