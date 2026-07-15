import Foundation
import SwiftData
import Testing
@testable import FUDO

/// HomeViewModel owns zero game math — it derives Home's three frames from GameStore.
/// These lock the derivations the frames read (banner metric, rank hints, delta badge)
/// and the two known pitfalls: a relaunch must never replay a celebration, nor re-show
/// a banner the user already closed.
@Suite(.serialized)
@MainActor
struct HomeViewModelTests {

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

    /// A view model on a clean slate. The dismissed-banner day lives in
    /// UserDefaults.standard, which outlives the in-memory container — clear it or a
    /// test inherits the previous one's dismissal. Build HomeViewModel DIRECTLY when
    /// a test is simulating a relaunch: that is exactly the state that must survive.
    private func makeViewModel(_ store: GameStore) -> HomeViewModel {
        UserDefaults.standard.removeObject(forKey: HomeViewModel.dismissedBannerDayKey)
        return HomeViewModel(store: store)
    }

    // MARK: screen state (frames 01 / 01b / 01c)

    @Test func screenStateFollowsTheChallengeThenTheDay() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        store.ensurePlayer(startingOVR: 49)
        let vm = makeViewModel(store)
        #expect(vm.screenState == .noChallenge)          // 01b — never an empty screen

        let challenge = try #require(store.startChallenge(preset: .monk30, durationDays: 30,
                                                          rules: fiveRules, reminderMinutes: 420))
        #expect(vm.screenState == .inProgress)           // 01
        #expect(vm.dayProgress == 0)

        for rule in challenge.activeRules { store.checkTask(rule) }
        #expect(vm.screenState == .dayComplete)          // 01c
        #expect(vm.dayProgress == 1)
        #expect(vm.completionMessage == "Day 1: complete. Return tomorrow.")
    }

    @Test func dayPillFallsBackToTheBrandMarkWithoutAChallenge() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        store.ensurePlayer(startingOVR: 49)
        let vm = makeViewModel(store)
        #expect(vm.dayPillLabel == "FUDO")
        #expect(!vm.streakIsAlive)

        try startMonk30(store)
        #expect(vm.dayPillLabel == "DAY 1 / 30")
    }

    // MARK: checklist

    @Test func checkedItemsSlideToTheBottomKeepingRuleOrder() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let vm = makeViewModel(store)
        let ruleOrder = vm.items.map(\.rule.title)
        #expect(ruleOrder == challenge.activeRules.map(\.title))

        let second = try #require(challenge.activeRules.dropFirst().first)
        store.checkTask(second)

        let after = vm.items
        #expect(after.count == 5)
        #expect(after.last?.rule.id == second.id)        // the checked one sank
        #expect(after.last?.isChecked == true)
        #expect(after.dropLast().map(\.rule.title) == ruleOrder.filter { $0 != second.title })
    }

    @Test func confirmCheckReturnsTheExactDeltaTheEngineRecorded() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store)
        let vm = makeViewModel(store)

        let item = try #require(vm.items.first)
        let granted = try #require(vm.confirmCheck(item))
        let recorded = try #require(store.currentLog()?.checks
            .first { $0.ruleID == item.rule.id }?.ovrDelta)
        #expect(granted == recorded)                     // the row floats the stored delta
        #expect(vm.checkPulseTrigger == 1)

        // An already-checked row pays nothing (no double-charge through the VM).
        let checked = try #require(vm.items.first { $0.isChecked })
        #expect(vm.confirmCheck(checked) == nil)
        #expect(vm.checkPulseTrigger == 1)
    }

    @Test func uncheckRefundsExactlyAndReordersBack() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store)
        let vm = makeViewModel(store)
        let player = try #require(store.player)
        let before = player.ovrValue

        let item = try #require(vm.items.first)
        _ = vm.confirmCheck(item)
        #expect(player.ovrValue > before)

        let checked = try #require(vm.items.first { $0.isChecked })
        vm.uncheck(checked)
        #expect(abs(player.ovrValue - before) < 1e-12)
        #expect(vm.items.allSatisfy { !$0.isChecked })
    }

    // MARK: celebration one-shot (known pitfall — a relaunch replays nothing)

    @Test func celebrationFiresOnTheLiveFlipOnlyAndNeverOnRelaunch() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let vm = makeViewModel(store)
        #expect(vm.celebrationTrigger == 0)

        for _ in 0..<(challenge.activeRules.count - 1) {
            _ = vm.confirmCheck(try #require(vm.items.first { !$0.isChecked }))
        }
        #expect(vm.celebrationTrigger == 0)              // 4/5 — nothing to celebrate yet

        _ = vm.confirmCheck(try #require(vm.items.first { !$0.isChecked }))
        #expect(vm.celebrationTrigger == 1)              // the day flipped under the finger
        #expect(vm.screenState == .dayComplete)

        // App killed and relaunched onto the same completed day: triggers start at 0,
        // so SenseiStageView has nothing to replay.
        let relaunched = makeViewModel(store)
        #expect(relaunched.screenState == .dayComplete)
        #expect(relaunched.celebrationTrigger == 0)
        #expect(relaunched.checkPulseTrigger == 0)
    }

    // MARK: incomplete banner (metric = the closure's PENALTY, not the day's net)

    @Test func incompleteBannerShowsThePenaltyNotTheDayNet() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        // Partial day: those gains were already on screen when earned, so the morning
        // drop is the penalty alone.
        for rule in challenge.activeRules.prefix(3) { store.checkTask(rule) }
        let day1Pool = try #require(store.currentLog()).dailyGainPool
        let day1Gains = try #require(store.currentLog()).checksTotal
        #expect(day1Gains > 0)

        clock.now = try date(day: 2)
        store.processRolloverIfNeeded()

        let vm = makeViewModel(store)
        let summary = try #require(vm.incompleteRollover)
        #expect(summary.dayCount == 1)
        #expect(abs(summary.ovrDrop - OVREngine.missedDayPenalty(pool: day1Pool)) < 1e-9)
        #expect(vm.showsIncompleteBanner)
    }

    @Test func consecutiveMissedDaysSumTheirPenalties() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        for rule in challenge.activeRules { store.checkTask(rule) }   // day 1 complete

        clock.now = try date(day: 5)                                   // app closed 3 days
        store.processRolloverIfNeeded()

        let vm = makeViewModel(store)
        let summary = try #require(vm.incompleteRollover)
        #expect(summary.dayCount == 3)                                 // days 2, 3, 4 — day 1 stops the walk
        let expected = challenge.dayLogs
            .filter { (2...4).contains($0.dayNumber) }
            .reduce(0.0) { $0 + max(0, $1.checksTotal - $1.ovrDelta) }
        #expect(abs(summary.ovrDrop - expected) < 1e-9)
    }

    @Test func aDismissedBannerSurvivesARelaunchOnTheSameDay() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store)
        clock.now = try date(day: 2)
        store.processRolloverIfNeeded()                                // day 1 closed, untouched

        let vm = makeViewModel(store)
        #expect(vm.showsIncompleteBanner)
        vm.dismissIncompleteBanner()
        #expect(!vm.showsIncompleteBanner)
        #expect(vm.incompleteRollover != nil)                          // the drop still happened

        // Relaunch — built directly, NOT through makeViewModel: the persisted dismissal
        // is exactly what must survive.
        #expect(!HomeViewModel(store: store).showsIncompleteBanner)

        // A new rollover day is a new banner.
        clock.now = try date(day: 3)
        store.processRolloverIfNeeded()
        #expect(HomeViewModel(store: store).showsIncompleteBanner)

        UserDefaults.standard.removeObject(forKey: HomeViewModel.dismissedBannerDayKey)
    }

    // MARK: OVR block

    @Test func ovrDeltaPrefersLiveGainsThenYesterdaysPenalty() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let vm = makeViewModel(store)
        #expect(vm.ovrDeltaToday == nil)                               // quiet dash, nothing moved

        store.checkTask(try #require(challenge.activeRules.first))
        #expect(vm.ovrDeltaToday == store.currentLog()?.checksTotal)
        #expect((vm.ovrDeltaToday ?? 0) > 0)

        let day1Pool = try #require(store.currentLog()).dailyGainPool
        clock.now = try date(day: 2)
        store.processRolloverIfNeeded()

        // Nothing checked today → the badge falls back to the morning penalty, the same
        // metric the banner shows, and it reads NEGATIVE.
        let fresh = makeViewModel(store)
        let delta = try #require(fresh.ovrDeltaToday)
        #expect(abs(delta + OVREngine.missedDayPenalty(pool: day1Pool)) < 1e-9)
        #expect(delta < 0)
        #expect(fresh.isYesterdayIncomplete)
    }

    /// The floor lock reaching the screen: Home reads the player through the engine
    /// helper, so 69.9 can never light up the Warrior band (audit 2026-07-15).
    @Test func displayedOVRIsFlooredAllTheWayToTheView() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store, startingOVR: 69.9)
        let player = try #require(store.player)
        let vm = makeViewModel(store)

        #expect(player.displayedOVR == OVREngine.displayedOVR(69.9))
        #expect(vm.displayedOVR == 69)
        #expect(vm.rank == .ascetic)
    }

    // MARK: rank progression (v2 hero — derived from Rank.floorOVR, no new data)

    @Test func rankHintsCountDownToTheNextFloor() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store, startingOVR: 61.5)      // Ascetic band 60…69, Warrior opens at 70
        let vm = makeViewModel(store)

        #expect(vm.displayedOVR == 61)
        #expect(vm.rank == .ascetic)
        #expect(vm.nextRank == .warrior)
        #expect(vm.pointsToNextRank == 9)              // 70 − 61
        #expect(abs(vm.rankProgress - 0.1) < 1e-9)     // (61 − 60) / 10
        #expect(vm.nextRankHint == "▸ WARRIOR · 9")
        #expect(vm.nextRankBarLabel == "NEXT WARRIOR · 9 PTS")
    }

    @Test func senseiHasNoNextRankAndAFullBar() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store, startingOVR: 95)
        let vm = makeViewModel(store)

        #expect(vm.rank == .sensei)
        #expect(vm.nextRank == nil)
        #expect(vm.pointsToNextRank == nil)
        #expect(vm.rankProgress == 1)
        #expect(vm.nextRankHint == "MAX RANK")
        #expect(vm.nextRankBarLabel == "MAX RANK")
    }

    // MARK: flame sheet

    @Test func flameWeekIsMondayFirstWithTodayCarryingTheDayRing() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let vm = makeViewModel(store)

        #expect(vm.flameWeek.count == 7)
        #expect(vm.flameWeek.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(vm.flameWeek.filter(\.isToday).count == 1)

        store.checkTask(try #require(challenge.activeRules.first))     // 1/5
        let today = try #require(vm.flameWeek.first { $0.isToday })
        guard case .today(let progress) = today.state else {
            Issue.record("today's pastille must mirror the day ring")
            return
        }
        #expect(abs(progress - 0.2) < 1e-9)
    }
}
