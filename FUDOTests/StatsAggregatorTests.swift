import Foundation
import SwiftData
import Testing
@testable import FUDO

/// Pure aggregation tests for `StatsAggregator` (Features/Stats). The aggregator only
/// reads a challenge's `activeRules` and `dayLogs`, so the scenarios craft `DayLog`s and
/// their `TaskCheck`s directly — no GameStore / OVR maths in the loop. Days run
/// consecutively up to a fixed "today"; `dayNumber n` is the challenge's day n.
///
/// Session invariants under test (2026-07-13): the current day is INCLUDED in rates and
/// counts, but a "missed" verdict needs a CLOSED day; trend is last-7 vs previous-7 with a
/// ±5-pt band; top/flop needs 5 closed days and 2 habits; a per-habit streak survives an
/// open, unchecked today and breaks on a closed miss.
@Suite(.serialized)
@MainActor
struct StatsAggregatorTests {

    /// Builds a fresh, wiped container with one challenge + rules, and lets a test append
    /// days. `today` is fixed; the challenge starts `days − 1` days before it.
    @MainActor
    private final class Scenario {
        let container: ModelContainer
        let context: ModelContext
        let challenge: Challenge
        let rules: [TaskRule]
        let today: Date
        private let cal = Calendar.current

        init(days: Int, ruleTitles: [String]) throws {
            let container = try SwiftDataTestSupport.freshContainer()
            let context = container.mainContext
            let calendar = Calendar.current
            let anchor = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
            let today = calendar.startOfDay(for: anchor)
            let start = try #require(calendar.date(byAdding: .day, value: -(days - 1), to: today))
            let challenge = Challenge(preset: .monk30, durationDays: max(days, 30), startDate: start,
                                      reminderMinutes: 420, startOVR: 50)
            context.insert(challenge)
            // Capture the locals, not `self` — `rules` isn't initialized yet.
            let rules = ruleTitles.enumerated().map { index, title -> TaskRule in
                let rule = TaskRule(title: title, iconName: "circle", sortOrder: index)
                rule.challenge = challenge
                context.insert(rule)
                return rule
            }
            self.container = container
            self.context = context
            self.today = today
            self.challenge = challenge
            self.rules = rules
        }

        /// Append day `dayNumber` (1-based). `held` = the rules checked that day.
        func addDay(_ dayNumber: Int, held: [TaskRule], closed: Bool, hour: Int = 8) throws {
            let start = cal.startOfDay(for: challenge.startDate)
            let date = try #require(cal.date(byAdding: .day, value: dayNumber - 1, to: start))
            let time = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            let log = DayLog(date: date, dayNumber: dayNumber, dailyGainPool: 1.0)
            log.checks = held.map { TaskCheck(ruleID: $0.id, checkedAt: time, ovrDelta: 0.1) }
            log.isClosed = closed
            log.isComplete = closed && held.count == rules.filter(\.isActive).count
            log.challenge = challenge
            context.insert(log)
        }

        var aggregator: StatsAggregator {
            StatsAggregator(challenge: challenge, calendar: cal, today: today)
        }
    }

    // MARK: - Completion % per window · today included · missed = closed only

    @Test func percentPerWindowIncludesTodayButMissedCountsClosedOnly() throws {
        let scenario = try Scenario(days: 10, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...9 { try scenario.addDay(day, held: [], closed: true) }   // 9 closed, never held
        try scenario.addDay(10, held: [a], closed: false)                       // today OPEN, held
        let agg = scenario.aggregator

        let week = try #require(agg.habitStats(.week).first)
        let month = try #require(agg.habitStats(.month).first)
        let challenge = try #require(agg.habitStats(.challenge).first)

        // Today counts toward %: challenge 1/10 = 10 %, week 1/7 ≈ 14 %. (0 % if it didn't.)
        #expect(challenge.completionPercent == 10)
        #expect(week.completionPercent == 14)
        // 30-day window == the whole run for a 10-day challenge.
        #expect(month.completionPercent == 10)

        // "missed" only on CLOSED days — today (open, unchecked) is not a miss.
        #expect(challenge.missedCount == 9)   // days 1…9
        #expect(week.missedCount == 6)        // last 7 = days 4…10; closed & unheld = days 4…9
    }

    @Test func summaryAggregatesCompletionChecksAndClosedDays() throws {
        let scenario = try Scenario(days: 6, ruleTitles: ["A", "B"])
        let (a, b) = (scenario.rules[0], scenario.rules[1])
        for day in 1...5 {                          // 5 closed days
            var held = [a]
            if day <= 3 { held.append(b) }          // A every day, B on days 1–3
            try scenario.addDay(day, held: held, closed: true)
        }
        try scenario.addDay(6, held: [a], closed: false)   // today: A held (counts), B not

        let summary = scenario.aggregator.summary(.challenge)
        // Held rule-days: A 6 + B 3 = 9, over 2 rules × 6 days = 12 → 75 %.
        #expect(summary.completionPercent == 75)
        #expect(summary.totalChecks == 9)
        #expect(summary.closedDayCount == 5)
    }

    // MARK: - Top / Flop threshold

    @Test func topFlopIsTooEarlyUnderFiveClosedDays() throws {
        let scenario = try Scenario(days: 4, ruleTitles: ["A", "B"])
        for day in 1...4 { try scenario.addDay(day, held: [scenario.rules[0]], closed: true) }
        #expect(scenario.aggregator.topFlop(.challenge) == nil)
    }

    @Test func topFlopRanksStrongestAndWeakestAtFiveDays() throws {
        let scenario = try Scenario(days: 5, ruleTitles: ["strong", "weak"])
        let (a, b) = (scenario.rules[0], scenario.rules[1])
        for day in 1...5 {
            var held = [a]                          // A held all 5
            if day == 1 { held.append(b) }          // B held once
            try scenario.addDay(day, held: held, closed: true)
        }
        let topFlop = try #require(scenario.aggregator.topFlop(.challenge))
        #expect(topFlop.strongest.id == a.id)
        #expect(topFlop.strongest.completionPercent == 100)
        #expect(topFlop.weakest.id == b.id)
        #expect(topFlop.weakest.completionPercent == 20)
    }

    @Test func topFlopNeedsTwoHabits() throws {
        let scenario = try Scenario(days: 6, ruleTitles: ["solo"])
        for day in 1...6 { try scenario.addDay(day, held: [scenario.rules[0]], closed: true) }
        #expect(scenario.aggregator.topFlop(.challenge) == nil)
    }

    // MARK: - Trend (last 7 vs previous 7, ±5 pts)

    @Test func trendRisesWhenRecentBeatsPrevious() throws {
        let scenario = try Scenario(days: 14, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...14 {
            try scenario.addDay(day, held: day >= 8 ? [a] : [], closed: true)   // last 7 all, prev 7 none
        }
        #expect(scenario.aggregator.habitStats(.challenge).first?.trend == .up)
    }

    @Test func trendFallsWhenRecentTrailsPrevious() throws {
        let scenario = try Scenario(days: 14, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...14 {
            try scenario.addDay(day, held: day <= 7 ? [a] : [], closed: true)   // prev 7 all, last 7 none
        }
        #expect(scenario.aggregator.habitStats(.challenge).first?.trend == .down)
    }

    @Test func trendStaysFlatWithinTheBand() throws {
        let scenario = try Scenario(days: 14, ruleTitles: ["A"])
        let a = scenario.rules[0]
        let heldDays: Set = [1, 2, 3, 4, 8, 9, 10, 11]   // 4 held in each half → 0-pt delta
        for day in 1...14 {
            try scenario.addDay(day, held: heldDays.contains(day) ? [a] : [], closed: true)
        }
        #expect(scenario.aggregator.habitStats(.challenge).first?.trend == .flat)
    }

    // MARK: - Per-habit streak

    @Test func streakSurvivesAnOpenUncheckedToday() throws {
        let scenario = try Scenario(days: 10, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...9 { try scenario.addDay(day, held: [a], closed: true) }
        try scenario.addDay(10, held: [], closed: false)   // today open, not checked — day isn't over
        #expect(scenario.aggregator.habitStats(.challenge).first?.streak == 9)
    }

    @Test func streakCountsAHeldToday() throws {
        let scenario = try Scenario(days: 10, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...9 { try scenario.addDay(day, held: [a], closed: true) }
        try scenario.addDay(10, held: [a], closed: false)   // today open, held → extends
        #expect(scenario.aggregator.habitStats(.challenge).first?.streak == 10)
    }

    @Test func streakBreaksAtAClosedMiss() throws {
        let scenario = try Scenario(days: 10, ruleTitles: ["A"])
        let a = scenario.rules[0]
        for day in 1...7 { try scenario.addDay(day, held: [a], closed: true) }
        try scenario.addDay(8, held: [], closed: true)      // closed miss
        try scenario.addDay(9, held: [a], closed: true)
        try scenario.addDay(10, held: [a], closed: false)   // today held
        // From today back: 10 held, 9 held, 8 missed (closed) → break → 2.
        #expect(scenario.aggregator.habitStats(.challenge).first?.streak == 2)
    }
}
