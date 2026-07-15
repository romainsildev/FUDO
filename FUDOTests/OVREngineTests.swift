import Foundation
import Testing
@testable import FUDO

struct OVREngineTests {
    private let calendar = Calendar.current

    private func date(year: Int = 2026, month: Int = 3, day: Int,
                      hour: Int = 0, minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    // MARK: startingOVR (§3a)

    @Test func startingOVRWorstAnswersIsBaseMin() {
        let answers = OnboardingAnswers(scrollTime: .sixHoursPlus, procrastination: .everyWeek,
                                        struggle: .cantEvenStart, commitment: .somewhat)
        #expect(OVREngine.startingOVR(from: answers) == Double(GameConfig.baseOVRMin))
    }

    @Test func startingOVRBestAnswersIsBaseMax() {
        let answers = OnboardingAnswers(scrollTime: .underTwoHours, procrastination: .stoppedLyingToMyself,
                                        struggle: .startStrongThenQuit, commitment: .extremely)
        #expect(OVREngine.startingOVR(from: answers) == Double(GameConfig.baseOVRMax))
    }

    @Test func startingOVRMatchesPRDExample43() {
        let answers = OnboardingAnswers(scrollTime: .twoToFourHours, procrastination: .everyWeek,
                                        struggle: .cantEvenStart, commitment: .somewhat)
        #expect(OVREngine.startingOVR(from: answers) == 43)
    }

    // MARK: pool & anti-farming (§3b)

    @Test func gainIsDegressiveTowards99() {
        #expect(OVREngine.dailyGainPool(currentOVR: 43) > OVREngine.dailyGainPool(currentOVR: 95))
        #expect(OVREngine.dailyGainPool(currentOVR: 95) > 0)
        #expect(OVREngine.dailyGainPool(currentOVR: GameConfig.ovrMax) == 0)
    }

    @Test func fullDayChecksSumExactlyToPool() {
        let pool = OVREngine.dailyGainPool(currentOVR: 61)
        var gained = 0.0
        for remaining in stride(from: 5, through: 1, by: -1) {
            gained += OVREngine.checkDelta(pool: pool, alreadyGained: gained,
                                           uncheckedActiveCount: remaining)
        }
        #expect(abs(gained - pool) < 1e-9)
    }

    @Test func checkDeltaIsZeroWhenPoolExhausted() {
        let pool = OVREngine.dailyGainPool(currentOVR: 43)
        #expect(OVREngine.checkDelta(pool: pool, alreadyGained: pool, uncheckedActiveCount: 3) == 0)
        #expect(OVREngine.checkDelta(pool: pool, alreadyGained: 0, uncheckedActiveCount: 0) == 0)
    }

    @Test func refundIsExactOpposite() {
        let delta = OVREngine.checkDelta(pool: 1.5, alreadyGained: 0.3, uncheckedActiveCount: 4)
        let check = TaskCheck(ruleID: UUID(), checkedAt: .now, ovrDelta: delta)
        #expect(OVREngine.refund(for: check) == -delta)
    }

    // MARK: penalty & closeDay (§3c)

    @Test func penaltyFloorsAtPenaltyMinNear99() {
        let pool = OVREngine.dailyGainPool(currentOVR: 98)
        #expect(OVREngine.missedDayPenalty(pool: pool) == GameConfig.penaltyMin)
    }

    @Test func penaltyIsFactorTimesPoolAtLowOVR() {
        let pool = OVREngine.dailyGainPool(currentOVR: 43)
        #expect(abs(OVREngine.missedDayPenalty(pool: pool) - pool * GameConfig.penaltyFactor) < 1e-9)
    }

    @Test func closeCompleteDayExtendsStreakWithoutTouchingOVR() {
        let closure = OVREngine.closeDay(isComplete: true, pool: 1.5, checksTotal: 1.5,
                                         currentOVR: 62, currentStreak: 4, bestStreak: 4)
        #expect(closure.newOVR == 62)
        #expect(closure.newStreak == 5)
        #expect(closure.newBestStreak == 5)
        #expect(closure.penalty == 0)
        #expect(closure.logDelta == 1.5)
    }

    @Test func closeIncompleteDayAppliesPenaltyAndBreaksStreak() {
        let pool = OVREngine.dailyGainPool(currentOVR: 61)
        let closure = OVREngine.closeDay(isComplete: false, pool: pool, checksTotal: 0.5,
                                         currentOVR: 61, currentStreak: 9, bestStreak: 9)
        let penalty = OVREngine.missedDayPenalty(pool: pool)
        #expect(abs(closure.newOVR - (61 - penalty)) < 1e-9)
        #expect(closure.newStreak == 0)
        #expect(closure.newBestStreak == 9)
        #expect(abs(closure.logDelta - (0.5 - penalty)) < 1e-9)
    }

    // MARK: grace period & rollover (§3e)

    @Test func effectiveDayAt159AMIsStillYesterday() throws {
        let now = try date(day: 11, hour: 1, minute: 59)
        let yesterday = try date(day: 10)
        #expect(OVREngine.effectiveDay(now: now, calendar: calendar) == yesterday)
    }

    @Test func effectiveDayAt201AMIsToday() throws {
        let now = try date(day: 11, hour: 2, minute: 1)
        let today = try date(day: 11)
        #expect(OVREngine.effectiveDay(now: now, calendar: calendar) == today)
    }

    @Test func daysToCloseHandlesMultipleMissedDaysInOrder() throws {
        // Last processed March 7, app reopened March 11 09:00 → close 8, 9, 10 in order.
        let expected = [try date(day: 8), try date(day: 9), try date(day: 10)]
        let days = OVREngine.daysToClose(now: try date(day: 11, hour: 9),
                                         lastProcessedDay: try date(day: 7),
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days == expected)
    }

    @Test func daysToCloseIsEmptyWhenUpToDate() throws {
        let days = OVREngine.daysToClose(now: try date(day: 11, hour: 9),
                                         lastProcessedDay: try date(day: 10),
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days.isEmpty)
    }

    @Test func daysToCloseStartsAtChallengeStartWhenNeverProcessed() throws {
        let expected = [try date(day: 1), try date(day: 2)]
        let days = OVREngine.daysToClose(now: try date(day: 3, hour: 9),
                                         lastProcessedDay: nil,
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days == expected)
    }

    // MARK: decay (§3d)

    @Test func decayTicksStartAfterGraceWindow() {
        #expect(OVREngine.totalDecayTicks(daysIdle: 6) == 0)
        #expect(OVREngine.totalDecayTicks(daysIdle: 7) == 0)   // J7 = notification day, before first tick
        #expect(OVREngine.totalDecayTicks(daysIdle: 9) == 0)
        #expect(OVREngine.totalDecayTicks(daysIdle: 10) == 1)
        #expect(OVREngine.totalDecayTicks(daysIdle: 13) == 2)
    }

    @Test func decayFloorsAtBottomOfCurrentRank() {
        #expect(OVREngine.decayedOVR(current: 61.5, ticks: 10) == 60)   // Ascetic floor
        #expect(OVREngine.decayedOVR(current: 90, ticks: 100) == 90)    // Sensei exact boundary holds
        #expect(Rank.from(ovr: OVREngine.decayedOVR(current: 74.2, ticks: 50)) == .warrior)
    }

    // MARK: rank & projection

    @Test func rankBoundaries() {
        #expect(OVREngine.rank(forOVR: 49) == .novice)
        #expect(OVREngine.rank(forOVR: 49.9) == .novice)
        #expect(OVREngine.rank(forOVR: 50) == .disciple)
        #expect(OVREngine.rank(forOVR: 89) == .master)
        #expect(OVREngine.rank(forOVR: 89.9) == .master)
        #expect(OVREngine.rank(forOVR: 90) == .sensei)
    }

    @Test func projectionMatchesPRDCalibration() {
        // DATA-MODEL §3b calibration table, base 43, perfect runs.
        #expect(Int(OVREngine.project(from: 43, days: 30).rounded(.down)) == 78)
        #expect(Int(OVREngine.project(from: 43, days: 60).rounded(.down)) == 91)
        #expect(Int(OVREngine.project(from: 43, days: 90).rounded(.down)) == 96)
        #expect(OVREngine.project(from: 43, days: 0) == 43)
    }

    // MARK: display floor (§3f)

    @Test func displayedOVRFloorsInsteadOfRounding() {
        #expect(OVREngine.displayedOVR(69.0) == 69)
        #expect(OVREngine.displayedOVR(69.5) == 69)    // half-up would read 70
        #expect(OVREngine.displayedOVR(69.99) == 69)
        #expect(OVREngine.displayedOVR(70.0) == 70)
        #expect(OVREngine.displayedOVR(0) == 0)
    }

    /// The lock (audit 2026-07-15): a rank must never be announced before it is
    /// earned. Rounding half-up broke this at every x.5 band edge — 69.5 is an
    /// Ascetic that would have displayed "70", the Warrior floor.
    @Test func displayedOVRNeverAnnouncesARankEarly() {
        for step in 0...396 {                          // 0 → 99 in 0.25 increments
            let stored = Double(step) * 0.25
            let shown = OVREngine.displayedOVR(stored)
            #expect(Rank.from(ovr: Double(shown)) == Rank.from(ovr: stored),
                    "stored \(stored) displayed as \(shown) — crossed a rank floor")
        }
    }
}
