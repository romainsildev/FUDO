import Foundation

/// Result of closing one day (§3c). Gains were already applied live at check time,
/// so a complete day leaves the OVR untouched here.
struct DayClosure: Equatable {
    let newOVR: Double
    let newStreak: Int
    let newBestStreak: Int
    let penalty: Double     // 0 when complete
    let logDelta: Double    // checksTotal − penalty → DayLog.ovrDelta
}

/// Single source of truth for the OVR formula (DATA-MODEL §3). Pure and stateless:
/// every number comes from GameConfig or Rank.floorOVR; callers own all persistence.
/// Onboarding projection (é10), Home, rollover and widget all call THIS — never duplicate.
enum OVREngine {

    // MARK: - Starting OVR (§3a)

    static func startingOVR(from answers: OnboardingAnswers) -> Double {
        let raw = Double(GameConfig.baseOVRMin + answers.totalPoints)
        return min(Double(GameConfig.baseOVRMax), max(Double(GameConfig.baseOVRMin), raw))
    }

    // MARK: - Daily pool & per-check deltas (§3b)

    /// Frozen into DayLog.dailyGainPool at day creation. Degressive toward 99;
    /// also the total delta of a 100 % day.
    static func dailyGainPool(currentOVR: Double) -> Double {
        max(0, (GameConfig.ovrMax - currentOVR) * GameConfig.dailyRate)
    }

    /// Share of the remaining pool granted by one check: remaining / unchecked count.
    /// Structural anti-farming: the sum of all check deltas can never exceed the frozen pool.
    static func checkDelta(pool: Double, alreadyGained: Double, uncheckedActiveCount: Int) -> Double {
        guard uncheckedActiveCount > 0 else { return 0 }
        return max(0, (pool - alreadyGained) / Double(uncheckedActiveCount))
    }

    /// Exact reversal of what that check granted — check/uncheck is perfectly neutral.
    static func refund(for check: TaskCheck) -> Double {
        -check.ovrDelta
    }

    // MARK: - Missed day (§3c)

    static func missedDayPenalty(pool: Double) -> Double {
        max(GameConfig.penaltyMin, pool * GameConfig.penaltyFactor)
    }

    static func closeDay(isComplete: Bool, pool: Double, checksTotal: Double,
                         currentOVR: Double, currentStreak: Int, bestStreak: Int) -> DayClosure {
        if isComplete {
            let streak = currentStreak + 1
            return DayClosure(newOVR: currentOVR, newStreak: streak,
                              newBestStreak: max(bestStreak, streak),
                              penalty: 0, logDelta: checksTotal)
        }
        // Partial gains stay earned (already applied live); no rank floor — losing a rank to failure is the threat.
        let penalty = missedDayPenalty(pool: pool)
        return DayClosure(newOVR: max(0, currentOVR - penalty), newStreak: 0,
                          newBestStreak: bestStreak,
                          penalty: penalty, logDelta: checksTotal - penalty)
    }

    // MARK: - Rollover clock (§3e)

    /// The gameplay day being played right now: startOfDay(now − graceHours).
    /// 1:59 AM still belongs to yesterday (silent grace); 2:00 AM starts today.
    static func effectiveDay(now: Date, calendar: Calendar) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -GameConfig.graceHours, to: now) ?? now
        return calendar.startOfDay(for: shifted)
    }

    /// Every day needing closure, chronological: from the day after `lastProcessedDay`
    /// (or the challenge start) up to but excluding the effective day.
    /// Handles multiple missed days — the app killed for 3 days yields 3 entries.
    static func daysToClose(now: Date, lastProcessedDay: Date?,
                            challengeStartDay: Date, calendar: Calendar) -> [Date] {
        let effective = effectiveDay(now: now, calendar: calendar)
        let start = calendar.startOfDay(for: challengeStartDay)
        var day: Date
        if let last = lastProcessedDay,
           let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) {
            day = max(next, start)
        } else {
            day = start
        }
        var result: [Date] = []
        while day < effective {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: - Idle decay (§3d)

    /// Total ticks owed after `daysIdle` days without an active challenge.
    /// 0 through day 9 (the J7 notification fires BEFORE the first tick), then 1 per interval.
    static func totalDecayTicks(daysIdle: Int) -> Int {
        guard daysIdle >= GameConfig.decayStartDays else { return 0 }
        return (daysIdle - GameConfig.decayStartDays) / GameConfig.decayIntervalDays
    }

    /// Applies ticks one by one, flooring each at the bottom of the CURRENT rank —
    /// a rank once earned is never lost to decay, the OVR slides to its band floor.
    static func decayedOVR(current: Double, ticks: Int) -> Double {
        var ovr = current
        for _ in 0..<max(0, ticks) {
            ovr = max(Rank.from(ovr: ovr).floorOVR, ovr - GameConfig.decayAmount)
        }
        return ovr
    }

    // MARK: - Rank & projection

    static func rank(forOVR ovr: Double) -> Rank {
        Rank.from(ovr: ovr)
    }

    /// Geometric convergence after `days` perfect days (§3b). The onboarding
    /// projection screen (é10) MUST call this — never a hand-drawn curve.
    static func project(from base: Double, days: Int) -> Double {
        let gap = (GameConfig.ovrMax - base) * pow(1 - GameConfig.dailyRate, Double(days))
        return min(GameConfig.ovrMax, GameConfig.ovrMax - gap)
    }
}
