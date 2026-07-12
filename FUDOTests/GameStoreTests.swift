import Foundation
import SwiftData
import Testing
@testable import FUDO

@Suite(.serialized)
@MainActor
struct GameStoreTests {

    /// Reference-typed clock: the store's nowProvider closure sees every mutation.
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeStore(startingAt now: Date) throws -> (GameStore, Clock) {
        let container = try SwiftDataTestSupport.freshContainer()
        let clock = Clock(now)
        let store = GameStore(modelContext: container.mainContext,
                              calendar: .current, nowProvider: { clock.now })
        return (store, clock)
    }

    private func date(day: Int, hour: Int = 9, minute: Int = 0) throws -> Date {
        try #require(Calendar.current.date(from: DateComponents(
            year: 2026, month: 3, day: day, hour: hour, minute: minute)))
    }

    private var fiveRules: [RuleDraft] {
        [RuleDraft(title: "Daily workout", iconName: "figure.strengthtraining.traditional"),
         RuleDraft(title: "Cold shower", iconName: "drop.fill"),
         RuleDraft(title: "Read 30 min", iconName: "book.fill"),
         RuleDraft(title: "Screen time under 1h", iconName: "iphone.slash"),
         RuleDraft(title: "Wake up before 7:00", iconName: "sunrise.fill")]
    }

    @discardableResult
    private func startMonk30(_ store: GameStore, startingOVR: Double = 49) throws -> Challenge {
        store.ensurePlayer(startingOVR: startingOVR)
        return try #require(store.startChallenge(preset: .monk30, durationDays: 30,
                                                 rules: fiveRules, reminderMinutes: 420))
    }

    // MARK: check / uncheck (§3b)

    @Test func checkThenUncheckIsPerfectlyNeutral() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let rule = try #require(challenge.activeRules.first)
        let before = player.ovrValue
        store.checkTask(rule)
        #expect(player.ovrValue > before)
        store.uncheckTask(rule)
        #expect(abs(player.ovrValue - before) < 1e-12)
        #expect(store.currentLog()?.checks.isEmpty == true)
    }

    @Test func checkingSameTaskTwicePaysOnce() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let rule = try #require(challenge.activeRules.first)
        store.checkTask(rule)
        let after = player.ovrValue
        store.checkTask(rule)
        #expect(player.ovrValue == after)
        #expect(store.currentLog()?.checks.count == 1)
    }

    @Test func fullDayConsumesExactlyThePool() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let pool = try #require(store.currentLog()).dailyGainPool
        let before = player.ovrValue
        for rule in challenge.activeRules { store.checkTask(rule) }
        #expect(abs(player.ovrValue - (before + pool)) < 1e-9)
    }

    // MARK: rollover (§3c + §3e)

    @Test func rolloverClosesIncompleteDayWithPenaltyAndBreaksStreak() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        for rule in challenge.activeRules { store.checkTask(rule) }   // day 1 complete
        clock.now = try date(day: 2)
        store.processRolloverIfNeeded()
        #expect(player.currentStreak == 1)
        let ovrAfterDay1 = player.ovrValue
        let day2Pool = try #require(store.currentLog()).dailyGainPool

        clock.now = try date(day: 3)                                   // day 2 never touched
        store.processRolloverIfNeeded()
        let penalty = OVREngine.missedDayPenalty(pool: day2Pool)
        #expect(abs(player.ovrValue - (ovrAfterDay1 - penalty)) < 1e-9)
        #expect(player.currentStreak == 0)
        #expect(player.bestStreak == 1)
        let day2Log = try #require(challenge.dayLogs.first { $0.dayNumber == 2 })
        #expect(day2Log.isClosed && !day2Log.isComplete)
    }

    @Test func threeKilledDaysProduceThreeOrderedPenalties() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        for rule in challenge.activeRules { store.checkTask(rule) }   // day 1 complete
        let historyBefore = player.ovrHistory.count

        clock.now = try date(day: 5)                                   // app killed 3 days
        store.processRolloverIfNeeded()

        let closed = challenge.dayLogs.filter(\.isClosed).sorted { $0.dayNumber < $1.dayNumber }
        #expect(closed.map(\.dayNumber) == [1, 2, 3, 4])
        #expect(closed[0].isComplete)
        #expect(closed[1...].allSatisfy { !$0.isComplete })
        #expect(player.currentStreak == 0)
        // 4 closures → 4 new history points, values strictly decreasing over the missed days
        let newPoints = Array(player.ovrHistory.suffix(from: historyBefore))
        #expect(newPoints.count == 4)
        #expect(newPoints[1].value > newPoints[2].value)
        #expect(newPoints[2].value > newPoints[3].value)
        // today (day 5) is open and playable
        #expect(store.currentLog()?.dayNumber == 5)
    }

    @Test func graceChecksAt159AMCountForYesterday() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1)) // day 1, 9:00 AM
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        for rule in challenge.activeRules.prefix(3) { store.checkTask(rule) }

        clock.now = try date(day: 2, hour: 1, minute: 59)   // grace window
        store.processRolloverIfNeeded()                      // silent — closes nothing
        for rule in challenge.activeRules.suffix(2) { store.checkTask(rule) }

        clock.now = try date(day: 2, hour: 2, minute: 1)     // grace over
        store.processRolloverIfNeeded()
        let day1Log = try #require(challenge.dayLogs.first { $0.dayNumber == 1 })
        #expect(day1Log.isClosed && day1Log.isComplete)      // the 1:59 checks counted for day 1
        #expect(day1Log.checks.count == 5)
        #expect(player.currentStreak == 1)
    }

    @Test func challengeCompletionIncrementsCounterAndFreezesEndOVR() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        store.ensurePlayer(startingOVR: 49)
        let challenge = try #require(store.startChallenge(preset: .custom, durationDays: 3,
                                                          rules: fiveRules, reminderMinutes: 420))
        let player = try #require(store.player)
        for day in 1...3 {
            clock.now = try date(day: day)
            store.processRolloverIfNeeded()
            for rule in challenge.activeRules { store.checkTask(rule) }
        }
        clock.now = try date(day: 4)
        store.processRolloverIfNeeded()
        #expect(challenge.status == .completed)
        #expect(player.completedChallengesCount == 1)
        #expect(challenge.endOVR == player.ovrValue)
        #expect(store.activeChallenge == nil)
        #expect(player.currentStreak == 3)
    }

    @Test func onlyOneActiveChallengeAtATime() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let first = try startMonk30(store)
        let second = store.startChallenge(preset: .hardcore90, durationDays: 90,
                                          rules: fiveRules, reminderMinutes: 420)
        #expect(second == nil)
        #expect(store.activeChallenge === first)
    }

    @Test func startChallengeRejectsEmptyAndOverMaxRules() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        store.ensurePlayer(startingOVR: 49)
        #expect(store.startChallenge(preset: .custom, durationDays: 30,
                                     rules: [], reminderMinutes: 420) == nil)
        let nine = (0..<(GameConfig.maxRules + 1)).map {
            RuleDraft(title: "Rule \($0)", iconName: "circle")
        }
        #expect(store.startChallenge(preset: .custom, durationDays: 30,
                                     rules: nine, reminderMinutes: 420) == nil)
    }

    // MARK: abandon + decay (§3d)

    @Test func abandonAppliesPenaltyBreaksStreakAndFreezesEndOVR() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let pool = try #require(store.currentLog()).dailyGainPool
        let before = player.ovrValue
        store.abandonChallenge()
        #expect(abs(player.ovrValue - (before - OVREngine.missedDayPenalty(pool: pool))) < 1e-9)
        #expect(player.currentStreak == 0)
        #expect(challenge.status == .abandoned)
        #expect(challenge.endOVR == player.ovrValue)
        #expect(store.activeChallenge == nil)
    }

    @Test func decayTicksAfterIdlePeriodAndFloorsAtRankBottom() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store, startingOVR: 61.5)   // Ascetic
        let player = try #require(store.player)
        store.abandonChallenge()                     // idle clock starts day 1
        let afterAbandon = player.ovrValue
        clock.now = try date(day: 14)                // 13 idle days → 2 ticks
        store.processRolloverIfNeeded()
        let expected = OVREngine.decayedOVR(current: afterAbandon, ticks: 2)
        #expect(player.ovrValue == expected)
        #expect(player.ovrValue >= player.rank.floorOVR)   // never below current rank floor
        store.processRolloverIfNeeded()              // same day: idempotent
        #expect(player.ovrValue == expected)
    }

    // MARK: rank-up (D6)

    @Test func rankUpFiresOncePerRank() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        store.ensurePlayer(startingOVR: 49.9)        // one check away from Disciple
        let challenge = try #require(store.startChallenge(preset: .monk30, durationDays: 30,
                                                          rules: fiveRules, reminderMinutes: 420))
        let player = try #require(store.player)
        store.checkTask(try #require(challenge.activeRules.first))
        #expect(player.rank == .disciple)
        #expect(store.consumeRankUp() == .disciple)
        #expect(store.pendingRankUp == nil)
        store.checkTask(try #require(challenge.activeRules.last))   // same rank — no re-celebration
        #expect(store.pendingRankUp == nil)
        #expect(player.highestRankReached == Rank.disciple.rawValue)
    }
}
