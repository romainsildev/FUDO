import Foundation

// MARK: - Value types (Stats-local, no persistence)

/// Trend of a completion rate: last 7 days vs the previous 7, ±5 pts threshold.
/// The ARROW carries the green/red — bars/rings stay vermillon (CLAUDE.md).
enum TrendDirection: Equatable { case up, down, flat }

/// The Stats-tab period summary card (frame 05).
struct PeriodSummary: Equatable {
    let completionPercent: Int
    let totalChecks: Int
    let bestDayLabel: String?   // "TUE" — nil when there's nothing done yet
    let closedDayCount: Int     // elapsed (closed) days in the window
}

/// One habit's aggregate over the window — the list row (frame 05) and the
/// strongest/weakest cards. `sparkline` is the last 7 days (held/missed), most
/// recent last; it is recent-form, independent of the selected period.
struct HabitStat: Identifiable, Equatable {
    let id: UUID
    let title: String
    let iconName: String
    let completionPercent: Int
    let sparkline: [Bool]
    let trend: TrendDirection
    let streak: Int
    let missedCount: Int
}

/// The two side-by-side cards. nil when there isn't enough data (min 5 closed days).
struct TopFlop: Equatable {
    let strongest: HabitStat
    let weakest: HabitStat
}

/// A bar in the habit-detail graph: a single day (7d) or a week bucket (30d/challenge).
struct HabitBar: Identifiable, Equatable {
    let id: Int
    let label: String
    let fill: Double     // 0…1 — day: 0/1 · week: completion rate
    let isMissed: Bool   // dead (vermillon-off) bar
    let isToday: Bool    // the in-progress day (7d only)
}

enum BarMode: Equatable { case days, weeks }

/// One row of the step-by-step timeline (frame 05b), most recent first.
struct TimelineEntry: Identifiable, Equatable {
    enum State: Equatable { case held, missed, todayOpen }
    let id: Int
    let dayNumber: Int
    let state: State
    let timeLabel: String?   // "7:42 AM" for held days
}

/// Everything the Habit-detail screen needs, precomputed.
struct HabitDetail: Equatable {
    let title: String
    let iconName: String
    let completionPercent: Int
    let streak: Int
    let totalChecks: Int
    let trend: TrendDirection
    let barMode: BarMode
    let bars: [HabitBar]
    let timeline: [TimelineEntry]
    let advice: String
}

// MARK: - Aggregator

/// Pure, stateless aggregation over one challenge's `DayLog.checks`, keyed by `ruleID`.
/// The single home for the stats maths — the Stats list and the Habit detail both call
/// it, nothing is duplicated (mirrors the "OVREngine is the only OVR formula" rule).
/// Reads existing data only; today's OPEN day is included in rates/counts (session
/// decision 2026-07-13 — the current day counts), but a *verdict* ("missed") still
/// needs a closed day.
struct StatsAggregator {
    let calendar: Calendar
    let today: Date              // startOfDay of the effective gameplay day
    let challengeStart: Date     // startOfDay of day 1
    let activeRules: [TaskRule]
    let allLogs: [DayLog]

    init(challenge: Challenge, calendar: Calendar, today: Date) {
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
        self.challengeStart = calendar.startOfDay(for: challenge.startDate)
        self.activeRules = challenge.activeRules
        self.allLogs = challenge.dayLogs
    }

    private static let enLocale = Locale(identifier: "en_US")
    private static let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened)
        .locale(enLocale)

    // MARK: Window

    /// Logs within the period, ascending — including today's open log ("include today").
    func windowLogs(_ period: StatsPeriod) -> [DayLog] {
        let start: Date
        if let days = period.trailingDays,
           let back = calendar.date(byAdding: .day, value: -(days - 1), to: today) {
            start = max(back, challengeStart)
        } else {
            start = challengeStart
        }
        return allLogs
            .filter { let d = calendar.startOfDay(for: $0.date); return d >= start && d <= today }
            .sorted { $0.date < $1.date }
    }

    /// Last `n` challenge days up to today, ascending (recent-form window).
    private func recentLogs(_ n: Int) -> [DayLog] {
        allLogs
            .filter { calendar.startOfDay(for: $0.date) <= today }
            .sorted { $0.date < $1.date }
            .suffix(n)
            .map { $0 }
    }

    // MARK: Per-day / per-habit primitives

    private func held(_ rule: TaskRule, in log: DayLog) -> Bool {
        log.checks.contains { $0.ruleID == rule.id }
    }

    private func isToday(_ log: DayLog) -> Bool {
        calendar.isDate(log.date, inSameDayAs: today)
    }

    /// A day counts as complete: frozen flag once closed, live check-count while open.
    private func isDayComplete(_ log: DayLog) -> Bool {
        if log.isClosed { return log.isComplete }
        let heldIDs = Set(log.checks.map(\.ruleID))
        let activeIDs = Set(activeRules.map(\.id))
        return !activeIDs.isEmpty && activeIDs.subtracting(heldIDs).isEmpty
    }

    private var activeIDs: Set<UUID> { Set(activeRules.map(\.id)) }

    // MARK: Rates

    /// Completion of one rule over a set of logs = held days / total days.
    private func completion(_ rule: TaskRule, in logs: [DayLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        let heldCount = logs.reduce(0) { $0 + (held(rule, in: $1) ? 1 : 0) }
        return Double(heldCount) / Double(logs.count)
    }

    private func percent(_ fraction: Double) -> Int { Int((fraction * 100).rounded()) }

    // MARK: Summary

    func summary(_ period: StatsPeriod) -> PeriodSummary {
        let logs = windowLogs(period)
        let closed = logs.filter(\.isClosed)
        let ruleCount = max(activeRules.count, 1)

        // Overall completion = held rule-days / (rules × days), today included.
        let heldRuleDays = logs.reduce(0) { acc, log in
            acc + activeRules.reduce(0) { $0 + (held($1, in: log) ? 1 : 0) }
        }
        let denom = ruleCount * logs.count
        let completion = denom > 0 ? Double(heldRuleDays) / Double(denom) : 0

        let totalChecks = logs.reduce(0) { acc, log in
            acc + log.checks.filter { activeIDs.contains($0.ruleID) }.count
        }

        return PeriodSummary(completionPercent: percent(completion),
                             totalChecks: totalChecks,
                             bestDayLabel: bestWeekday(in: logs),
                             closedDayCount: closed.count)
    }

    /// Weekday (abbrev, uppercased) with the highest average daily completion.
    /// nil when nothing has been done — a "best day" would be meaningless.
    private func bestWeekday(in logs: [DayLog]) -> String? {
        guard !logs.isEmpty else { return nil }
        var sumByWeekday: [Int: Double] = [:]
        var countByWeekday: [Int: Int] = [:]
        var anyDone = false
        for log in logs {
            let wd = calendar.component(.weekday, from: log.date)
            let frac = dayCompletionFraction(log)
            if frac > 0 { anyDone = true }
            sumByWeekday[wd, default: 0] += frac
            countByWeekday[wd, default: 0] += 1
        }
        guard anyDone else { return nil }
        let best = sumByWeekday
            .map { (wd: $0.key, avg: $0.value / Double(countByWeekday[$0.key] ?? 1)) }
            .max { $0.avg < $1.avg }
        guard let best, let date = someDate(forWeekday: best.wd, in: logs) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).locale(Self.enLocale)).uppercased()
    }

    private func dayCompletionFraction(_ log: DayLog) -> Double {
        guard !activeRules.isEmpty else { return 0 }
        let heldCount = activeRules.reduce(0) { $0 + (held($1, in: log) ? 1 : 0) }
        return Double(heldCount) / Double(activeRules.count)
    }

    private func someDate(forWeekday wd: Int, in logs: [DayLog]) -> Date? {
        logs.first { calendar.component(.weekday, from: $0.date) == wd }?.date
    }

    // MARK: Per-habit list

    func habitStats(_ period: StatsPeriod) -> [HabitStat] {
        let logs = windowLogs(period)
        return activeRules.map { rule in
            let closedNotHeld = logs.filter { $0.isClosed && !held(rule, in: $0) }.count
            return HabitStat(id: rule.id,
                             title: rule.title,
                             iconName: rule.iconName,
                             completionPercent: percent(completion(rule, in: logs)),
                             sparkline: sparkline(rule),
                             trend: trend(rule),
                             streak: streak(rule),
                             missedCount: closedNotHeld)
        }
    }

    /// Last 7 challenge days, held/missed, most recent last (recent-form glance).
    private func sparkline(_ rule: TaskRule) -> [Bool] {
        recentLogs(7).map { held(rule, in: $0) }
    }

    /// Consecutive held days ending at the most recent day. Today, while still open
    /// and unchecked, does not break the streak (the day isn't over) — it just isn't
    /// counted yet; a held today extends it.
    private func streak(_ rule: TaskRule) -> Int {
        let desc = allLogs
            .filter { calendar.startOfDay(for: $0.date) <= today }
            .sorted { $0.date > $1.date }
        var s = 0
        for log in desc {
            if held(rule, in: log) { s += 1 }
            else if isToday(log) && !log.isClosed { continue }
            else { break }
        }
        return s
    }

    /// Last 7 days vs the previous 7 (challenge-wide, today included), ±5 pts.
    private func trend(_ rule: TaskRule) -> TrendDirection {
        let recent = recentLogs(14)
        guard recent.count >= 4 else { return .flat }   // too little to call a direction
        let last = Array(recent.suffix(7))
        let prev = Array(recent.dropLast(7))
        guard !prev.isEmpty else { return .flat }
        let delta = completion(rule, in: last) - completion(rule, in: prev)
        if delta >= 0.05 { return .up }
        if delta <= -0.05 { return .down }
        return .flat
    }

    // MARK: Top / Flop

    /// nil unless there are ≥5 closed days AND ≥2 habits — otherwise "too early".
    func topFlop(_ period: StatsPeriod) -> TopFlop? {
        let logs = windowLogs(period)
        guard logs.filter(\.isClosed).count >= 5, activeRules.count >= 2 else { return nil }
        let stats = habitStats(period)
        guard let strongest = stats.max(by: { $0.completionPercent < $1.completionPercent }),
              let weakest = stats.min(by: { $0.completionPercent < $1.completionPercent }),
              strongest.id != weakest.id
        else { return nil }
        return TopFlop(strongest: strongest, weakest: weakest)
    }

    // MARK: Habit detail

    func detail(for rule: TaskRule, period: StatsPeriod) -> HabitDetail {
        let logs = windowLogs(period)
        let heldDays = logs.filter { held(rule, in: $0) }.count
        let mode: BarMode = period == .week ? .days : .weeks
        return HabitDetail(title: rule.title,
                           iconName: rule.iconName,
                           completionPercent: percent(completion(rule, in: logs)),
                           streak: streak(rule),
                           totalChecks: heldDays,
                           trend: trend(rule),
                           barMode: mode,
                           bars: mode == .days ? dayBars(rule) : weekBars(rule, logs: logs),
                           timeline: timeline(rule, logs: logs),
                           advice: HabitAdvice.line(for: rule, aggregator: self, period: period))
    }

    /// 7 day-bars (most recent last): held = full vermillon, missed = dead, today = in-progress.
    private func dayBars(_ rule: TaskRule) -> [HabitBar] {
        recentLogs(7).enumerated().map { index, log in
            let isHeld = held(rule, in: log)
            let today = isToday(log)
            return HabitBar(id: index,
                            label: log.date.formatted(.dateTime.weekday(.narrow).locale(Self.enLocale)),
                            fill: isHeld ? 1 : 0,
                            isMissed: !isHeld && log.isClosed,
                            isToday: today)
        }
    }

    /// Weekly buckets across the window — bar height = that week's completion rate.
    private func weekBars(_ rule: TaskRule, logs: [DayLog]) -> [HabitBar] {
        guard !logs.isEmpty else { return [] }
        // Group by whole weeks counted forward from the challenge start.
        var buckets: [Int: [DayLog]] = [:]
        for log in logs {
            let day = calendar.dateComponents([.day], from: challengeStart,
                                              to: calendar.startOfDay(for: log.date)).day ?? 0
            buckets[day / 7, default: []].append(log)
        }
        return buckets.keys.sorted().enumerated().map { index, weekIndex in
            let weekLogs = buckets[weekIndex] ?? []
            let rate = completion(rule, in: weekLogs)
            return HabitBar(id: index,
                            label: "W\(weekIndex + 1)",
                            fill: rate,
                            isMissed: rate == 0,
                            isToday: false)
        }
    }

    /// Step-by-step, most recent first, over the window.
    private func timeline(_ rule: TaskRule, logs: [DayLog]) -> [TimelineEntry] {
        logs.reversed().enumerated().map { index, log in
            let state: TimelineEntry.State
            var time: String?
            if let check = log.checks.first(where: { $0.ruleID == rule.id }) {
                state = .held
                time = check.checkedAt.formatted(Self.timeStyle)
            } else if isToday(log) && !log.isClosed {
                state = .todayOpen
            } else {
                state = .missed
            }
            return TimelineEntry(id: index, dayNumber: log.dayNumber, state: state, timeLabel: time)
        }
    }

    // MARK: Advice inputs (exposed to HabitAdvice)

    /// Weekend (Sat/Sun) completion gap vs weekdays over the window's closed days.
    /// Positive = habit is weaker on weekends. 0 when there's no weekend sample.
    func weekendGap(for rule: TaskRule, period: StatsPeriod) -> Double {
        let logs = windowLogs(period).filter(\.isClosed)
        let weekend = logs.filter { [1, 7].contains(calendar.component(.weekday, from: $0.date)) }
        let weekday = logs.filter { ![1, 7].contains(calendar.component(.weekday, from: $0.date)) }
        guard !weekend.isEmpty, !weekday.isEmpty else { return 0 }
        return completion(rule, in: weekday) - completion(rule, in: weekend)
    }

    /// Weekday (1…7) where the habit falls the most, if clearly below the mean. nil otherwise.
    func worstWeekday(for rule: TaskRule, period: StatsPeriod) -> Int? {
        let logs = windowLogs(period).filter(\.isClosed)
        guard logs.count >= 5 else { return nil }
        var rateByWeekday: [Int: (held: Int, total: Int)] = [:]
        for log in logs {
            let wd = calendar.component(.weekday, from: log.date)
            var e = rateByWeekday[wd, default: (0, 0)]
            e.held += held(rule, in: log) ? 1 : 0
            e.total += 1
            rateByWeekday[wd] = e
        }
        let rates = rateByWeekday
            .filter { $0.value.total >= 2 }
            .map { (wd: $0.key, rate: Double($0.value.held) / Double($0.value.total)) }
        guard rates.count >= 2, let worst = rates.min(by: { $0.rate < $1.rate }) else { return nil }
        let mean = rates.reduce(0.0) { $0 + $1.rate } / Double(rates.count)
        return (worst.rate <= 0.5 && mean - worst.rate >= 0.2) ? worst.wd : nil
    }

    /// Average hold hour (0…23) over held days, nil when never held.
    func averageHoldHour(for rule: TaskRule, period: StatsPeriod) -> Int? {
        let times = windowLogs(period)
            .compactMap { $0.checks.first(where: { $0.ruleID == rule.id })?.checkedAt }
        guard !times.isEmpty else { return nil }
        let hours = times.map { calendar.component(.hour, from: $0) }
        return Int((Double(hours.reduce(0, +)) / Double(hours.count)).rounded())
    }

    func completionFraction(for rule: TaskRule, period: StatsPeriod) -> Double {
        completion(rule, in: windowLogs(period))
    }

    func trendDirection(for rule: TaskRule) -> TrendDirection { trend(rule) }
    func streakCount(for rule: TaskRule) -> Int { streak(rule) }

    func weekdayName(_ weekday: Int) -> String {
        // 1 = Sunday … 7 = Saturday. Build a reference date and format it.
        let ref = calendar.date(bySetting: .weekday, value: weekday, of: today) ?? today
        return ref.formatted(.dateTime.weekday(.wide).locale(Self.enLocale))
    }

    // MARK: Overall advice (Stats tab)

    func overallAdvice(_ period: StatsPeriod) -> String {
        guard !activeRules.isEmpty else {
            return "Start checking in — your patterns show up after a few days."
        }
        guard windowLogs(period).filter(\.isClosed).count >= 5 else {
            return "Keep logging. After five days the patterns start to talk."
        }
        // Cross-habit weekend leak first — the highest-signal collective pattern.
        let weekendLeakers = activeRules.filter { weekendGap(for: $0, period: period) >= 0.25 }
        if weekendLeakers.count >= max(2, activeRules.count / 2) {
            return "Weekends are your leak — most habits slip on Saturday and Sunday."
        }
        // Otherwise coach the weakest habit.
        if let flop = habitStats(period).min(by: { $0.completionPercent < $1.completionPercent }),
           let rule = activeRules.first(where: { $0.id == flop.id }) {
            return HabitAdvice.line(for: rule, aggregator: self, period: period)
        }
        return "Steady work. Stack another clean day."
    }
}

// MARK: - Local advice rules (no AI at MVP)

/// One-line, habit-scoped advice from simple local rules, priority-ordered. English,
/// direct, second person (CLAUDE.md copy tone). The habit title is interpolated.
enum HabitAdvice {
    static func line(for rule: TaskRule, aggregator: StatsAggregator, period: StatsPeriod) -> String {
        let title = rule.title
        let completion = aggregator.completionFraction(for: rule, period: period)
        let trend = aggregator.trendDirection(for: rule)
        let streak = aggregator.streakCount(for: rule)

        if aggregator.weekendGap(for: rule, period: period) >= 0.25 {
            return "\(title) gets skipped on weekends — lock it in before noon."
        }
        if let hour = aggregator.averageHoldHour(for: rule, period: period),
           hour >= 21, completion < 0.85 {
            return "You leave \(title.lowercasedFirst) for late — do it earlier, before the day gets away."
        }
        if let wd = aggregator.worstWeekday(for: rule, period: period) {
            return "\(title) tends to fall on \(aggregator.weekdayName(wd))s — plan it the night before."
        }
        if trend == .down {
            return "You've eased off \(title.lowercasedFirst) lately — reset it today."
        }
        if completion < 0.5 {
            return "\(title) is your weak link — one clean week resets it."
        }
        if streak >= 5 || trend == .up {
            return "\(title) is dialed in — \(streak)-day streak. Protect it."
        }
        return "\(title): steady. Keep stacking days."
    }
}

private extension String {
    /// Lowercases only the first character — for mid-sentence interpolation of a title.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
