import Foundation
import Testing
@testable import FUDO

/// The S9 notification engine's brain is the PURE planner — no system calls, so the
/// invariants (completed day = silence, hard cap 2/day, conditional daily, evening
/// skipped after 20:30, decay only between challenges) are verified here. The
/// imperative install is a device concern (manual DEBUG plan).
struct NotificationPlannerTests {

    // A fixed UTC clock so "today at 20:30" is deterministic on any machine.
    private static func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static func date(_ hour: Int, _ minute: Int = 0,
                            day: Int = 23, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 7, day: day,
                                      hour: hour, minute: minute))!
    }

    /// Input with sane defaults (active challenge, incomplete, both switches on,
    /// reminder 07:00, streak 5, now = noon) — each test overrides what it probes.
    private static func input(
        now: Date,
        cal: Calendar,
        hasActiveChallenge: Bool = true,
        dayComplete: Bool = false,
        remainingTasks: Int = 3,
        streak: Int = 5,
        reminderMinutes: Int = 7 * 60,
        lastDayClosedAt: Date? = nil,
        dailyEnabled: Bool = true,
        eveningEnabled: Bool = true
    ) -> NotificationService.Planner.Input {
        .init(now: now, calendar: cal, hasActiveChallenge: hasActiveChallenge,
              dayComplete: dayComplete, remainingTasks: remainingTasks, streak: streak,
              reminderMinutes: reminderMinutes, lastDayClosedAt: lastDayClosedAt,
              dailyEnabled: dailyEnabled, eveningEnabled: eveningEnabled)
    }

    private func plan(_ input: NotificationService.Planner.Input) -> [NotificationCopy.Kind] {
        NotificationService.Planner.plan(input).map(\.kind)
    }

    // MARK: - Completed day = zero notifications that day

    @Test func completedDayScheduleNothingToday() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        // Daily off → nothing at all.
        #expect(NotificationService.Planner.plan(
            Self.input(now: noon, cal: cal, dayComplete: true, dailyEnabled: false)).isEmpty)
        // Daily on → only tomorrow's daily, never a nudge today.
        let kinds = plan(Self.input(now: noon, cal: cal, dayComplete: true))
        #expect(kinds == [.dailyReminder])
    }

    @Test func completedDayDailyLooksToTomorrow() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let planned = NotificationService.Planner.plan(
            Self.input(now: noon, cal: cal, dayComplete: true))
        let fire = try! #require(planned.first?.fireDate)
        // 07:00 the NEXT day.
        #expect(fire == Self.date(7, day: 24, cal: cal))
    }

    // MARK: - Hard cap: daily counts, then evening OR streak (never all three)

    @Test func dailyOnAllowsOnlyOneEveningNudge() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        // Reminder 07:00 already passed → daily fires tomorrow but STILL counts today.
        let kinds = plan(Self.input(now: noon, cal: cal))
        #expect(kinds == [.dailyReminder, .eveningReminder])   // streak capped out
        #expect(kinds.count <= 2)
    }

    @Test func dailyOffAllowsBothEveningAndStreak() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let kinds = plan(Self.input(now: noon, cal: cal, dailyEnabled: false))
        #expect(kinds == [.eveningReminder, .streakDanger])
        #expect(kinds.count <= 2)
    }

    @Test func neverAllThree() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let kinds = plan(Self.input(now: noon, cal: cal))
        #expect(!(kinds.contains(.eveningReminder) && kinds.contains(.streakDanger)))
    }

    // MARK: - Evening skipped when the reminder is after 20:30

    @Test func reminderAfterEveningSkipsEveningKeepsStreak() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        // Reminder 21:00 (> 20:30): evening dropped, daily(today 21:00) + streak(22:30).
        let planned = NotificationService.Planner.plan(
            Self.input(now: noon, cal: cal, reminderMinutes: 21 * 60))
        let kinds = planned.map(\.kind)
        #expect(kinds == [.dailyReminder, .streakDanger])
        #expect(!kinds.contains(.eveningReminder))
        // Daily fires TODAY at 21:00 (still ahead).
        #expect(planned.first?.fireDate == Self.date(21, cal: cal))
    }

    // MARK: - Streak danger needs a live streak

    @Test func noStreakNoStreakNotif() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let kinds = plan(Self.input(now: noon, cal: cal, streak: 0, dailyEnabled: false))
        #expect(kinds == [.eveningReminder])
    }

    // MARK: - Evening toggle gates BOTH evening and streak

    @Test func eveningToggleOffDropsBoth() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let kinds = plan(Self.input(now: noon, cal: cal, eveningEnabled: false))
        #expect(kinds == [.dailyReminder])
    }

    // MARK: - Daily fires TODAY when the reminder time is still ahead

    @Test func dailyFiresTodayWhenReminderAhead() {
        let cal = Self.calendar()
        let earlyMorning = Self.date(6, cal: cal)   // before 07:00
        let planned = NotificationService.Planner.plan(
            Self.input(now: earlyMorning, cal: cal, eveningEnabled: false))
        #expect(planned.first?.kind == .dailyReminder)
        #expect(planned.first?.fireDate == Self.date(7, cal: cal))   // today 07:00
    }

    // MARK: - Late night: every window already passed

    @Test func lateNightSchedulesNothingButNextDaily() {
        let cal = Self.calendar()
        let lateNight = Self.date(23, cal: cal)   // past 20:30 AND 22:30
        // Daily off → nothing (both nudges' windows gone).
        #expect(NotificationService.Planner.plan(
            Self.input(now: lateNight, cal: cal, dailyEnabled: false)).isEmpty)
        // Daily on → only tomorrow's daily.
        #expect(plan(Self.input(now: lateNight, cal: cal)) == [.dailyReminder])
    }

    // MARK: - Decay: only WITHOUT an active challenge, day 7 idle

    @Test func decayWarningSevenDaysAfterIdle() {
        let cal = Self.calendar()
        let now = Self.date(9, day: 23, cal: cal)
        let idle = Self.date(9, day: 20, cal: cal)   // closed 3 days ago
        let planned = NotificationService.Planner.plan(
            Self.input(now: now, cal: cal, hasActiveChallenge: false, lastDayClosedAt: idle))
        #expect(planned.map(\.kind) == [.decayWarning])
        // Fires at noon on day 7 after the idle start (20 + 7 = 27 → July 27, 12:00).
        #expect(planned.first?.fireDate == Self.date(12, day: 27, cal: cal))
    }

    @Test func noDecayWithoutIdleClock() {
        let cal = Self.calendar()
        let now = Self.date(9, cal: cal)
        #expect(NotificationService.Planner.plan(
            Self.input(now: now, cal: cal, hasActiveChallenge: false, lastDayClosedAt: nil)).isEmpty)
    }

    @Test func decayGatedByDailyToggle() {
        let cal = Self.calendar()
        let now = Self.date(9, day: 23, cal: cal)
        let idle = Self.date(9, day: 20, cal: cal)
        // Daily switch OFF → no decay nudge (only trial_d1 is toggle-immune).
        #expect(NotificationService.Planner.plan(
            Self.input(now: now, cal: cal, hasActiveChallenge: false,
                       lastDayClosedAt: idle, dailyEnabled: false)).isEmpty)
    }

    @Test func activeChallengeNeverSchedulesDecay() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let idle = Self.date(9, day: 1, cal: cal)   // stale clock, but a challenge is active
        let kinds = plan(Self.input(now: noon, cal: cal, lastDayClosedAt: idle))
        #expect(!kinds.contains(.decayWarning))
    }

    // MARK: - Bodies carry the real counts (copy)

    @Test func eveningBodyReflectsRemainingTasks() {
        let cal = Self.calendar()
        let noon = Self.date(12, cal: cal)
        let planned = NotificationService.Planner.plan(
            Self.input(now: noon, cal: cal, remainingTasks: 3, dailyEnabled: false))
        let evening = try! #require(planned.first { $0.kind == .eveningReminder })
        #expect(evening.body == "You have 3 tasks left. 3h30 before the penalty.")
    }

    @Test func copyIsSingularAtOne() {
        #expect(NotificationCopy.eveningBody(tasksLeft: 1) == "You have 1 task left. 3h30 before the penalty.")
        #expect(NotificationCopy.streakDangerBody(streak: 1) == "Your 1-day streak dies at midnight.")
        #expect(NotificationCopy.streakDangerBody(streak: 12) == "Your 12-day streak dies at midnight.")
    }

    @Test func trialCopyKeepsTheBillingPromise() {
        #expect(NotificationCopy.trialD1Body == "Your trial ends tomorrow. Keep your OVR climbing?")
    }

    // MARK: - Identifiers are stable slugs (analytics + reschedule keys)

    @Test func identifiersAreStableSlugs() {
        #expect(NotificationCopy.Kind.dailyReminder.id == "daily_reminder")
        #expect(NotificationCopy.Kind.eveningReminder.id == "evening_reminder")
        #expect(NotificationCopy.Kind.streakDanger.id == "streak_danger")
        #expect(NotificationCopy.Kind.trialD1.id == "trial_d1")
        #expect(NotificationCopy.Kind.decayWarning.id == "decay_warning")
        #expect(NotificationCopy.Kind.rankUp.id == "rank_up")
    }
}
