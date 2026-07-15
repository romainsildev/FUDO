# Data Layer + Game Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the full SwiftData data layer, the pure OVREngine, the GameStore mutation path, unit tests and the DebugSeed replay dataset — zero feature screens.

**Architecture:** 4 `@Model` entities persist state; `OVREngine` (stateless enum) owns every formula; `GameStore` (`@MainActor @Observable`) is the single mutation path and enforces invariants (singleton PlayerState, one active challenge, DayLog uniqueness, D6 rank-up mark). App wiring: container in `FUDOApp.init`, rollover on scene-active in `RootView`.

**Tech Stack:** Swift / SwiftUI iOS 17+, SwiftData, Swift Testing. Zero new dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-12-data-layer-design.md` · rules source: `docs/DATA-MODEL.md`.
- `@Observable` (never `ObservableObject`) · no `!` force unwrap · no `try!` on SwiftData ops · English code + comments.
- Every gameplay number comes from `GameConfig` (`FUDO/Core/Game/GameConfig.swift`, already exists — do NOT touch) or `Rank.floorOVR`. Zero magic numbers.
- `TaskCheck`, `OVRPoint`, `ChallengePreset`, `ChallengeStatus`, `Rank` already exist in `FUDO/Core/Models/SharedTypes.swift` — reuse, do NOT redefine.
- All "day" dates normalized `calendar.startOfDay(for:)`. Effective gameplay day = `startOfDay(now − graceHours)`.
- **Machine 16 GB rule (CLAUDE.md, overrides per-step red/green):** per-task verification = compile-only `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'` (no sim boot). Tests are written per task but EXECUTED once, in Task 6, on one booted sim. Never two `xcodebuild` concurrently.
- `FUDO/` and `FUDOTests/` are Xcode-synchronized folders — new files are picked up automatically, no pbxproj edit.
- Commit after each task (message in task).

---

### Task 1: OnboardingAnswers + OVREngine + engine tests

**Files:**
- Create: `FUDO/Core/Game/OnboardingAnswers.swift`
- Create: `FUDO/Core/Game/OVREngine.swift`
- Test: `FUDOTests/OVREngineTests.swift`

**Interfaces:**
- Consumes: `GameConfig`, `TaskCheck`, `Rank` (existing).
- Produces: `OnboardingAnswers` (struct + 4 enums with `points`), `OVREngine` full static surface incl. `DayClosure`, used verbatim by Tasks 3–5.

- [ ] **Step 1: Write `OnboardingAnswers.swift`**

```swift
import Foundation

/// Typed onboarding answers → starting-OVR points (DATA-MODEL §3a).
/// Each case carries its own points so the scale lives here and nowhere else;
/// the onboarding screens (é2/é4/é7/é13) will map their options onto these cases.
struct OnboardingAnswers: Equatable {
    let scrollTime: ScrollTime
    let procrastination: Procrastination
    let struggle: Struggle
    let commitment: Commitment

    enum ScrollTime: CaseIterable {
        case underTwoHours, twoToFourHours, fourToSixHours, sixHoursPlus
        var points: Int {
            switch self {
            case .underTwoHours: 4
            case .twoToFourHours: 3
            case .fourToSixHours: 1
            case .sixHoursPlus: 0
            }
        }
    }

    enum Procrastination: CaseIterable {
        case stoppedLyingToMyself, everyMonth, everyWeek
        var points: Int {
            switch self {
            case .stoppedLyingToMyself: 2
            case .everyMonth: 1
            case .everyWeek: 0
            }
        }
    }

    enum Struggle: CaseIterable {
        case startStrongThenQuit, threeDaysMax, cantEvenStart
        var points: Int {
            switch self {
            case .startStrongThenQuit: 2
            case .threeDaysMax: 1
            case .cantEvenStart: 0
            }
        }
    }

    enum Commitment: CaseIterable {
        case extremely, very, somewhat
        var points: Int {
            switch self {
            case .extremely: 2
            case .very: 1
            case .somewhat: 0
            }
        }
    }

    var totalPoints: Int {
        scrollTime.points + procrastination.points + struggle.points + commitment.points
    }
}
```

- [ ] **Step 2: Write `OVREngine.swift`**

```swift
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
```

- [ ] **Step 3: Write `FUDOTests/OVREngineTests.swift`**

```swift
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
        #expect(OVREngine.effectiveDay(now: now, calendar: calendar) == (try date(day: 10)))
    }

    @Test func effectiveDayAt201AMIsToday() throws {
        let now = try date(day: 11, hour: 2, minute: 1)
        #expect(OVREngine.effectiveDay(now: now, calendar: calendar) == (try date(day: 11)))
    }

    @Test func daysToCloseHandlesMultipleMissedDaysInOrder() throws {
        // Last processed March 7, app reopened March 11 09:00 → close 8, 9, 10 in order.
        let days = OVREngine.daysToClose(now: try date(day: 11, hour: 9),
                                         lastProcessedDay: try date(day: 7),
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days == [try date(day: 8), try date(day: 9), try date(day: 10)])
    }

    @Test func daysToCloseIsEmptyWhenUpToDate() throws {
        let days = OVREngine.daysToClose(now: try date(day: 11, hour: 9),
                                         lastProcessedDay: try date(day: 10),
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days.isEmpty)
    }

    @Test func daysToCloseStartsAtChallengeStartWhenNeverProcessed() throws {
        let days = OVREngine.daysToClose(now: try date(day: 3, hour: 9),
                                         lastProcessedDay: nil,
                                         challengeStartDay: try date(day: 1),
                                         calendar: calendar)
        #expect(days == [try date(day: 1), try date(day: 2)])
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
}
```

- [ ] **Step 4: Compile-only check**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** TEST BUILD SUCCEEDED **` (verify scheme name first with `xcodebuild -list` if it fails).

- [ ] **Step 5: Commit**

```bash
git add FUDO/Core/Game/OnboardingAnswers.swift FUDO/Core/Game/OVREngine.swift FUDOTests/OVREngineTests.swift
git commit -m "feat: OVREngine — pure OVR formula + typed onboarding answers"
```

---

### Task 2: SwiftData @Model entities

**Files:**
- Create: `FUDO/Core/Models/Challenge.swift`
- Create: `FUDO/Core/Models/TaskRule.swift`
- Create: `FUDO/Core/Models/DayLog.swift`
- Create: `FUDO/Core/Models/PlayerState.swift`

**Interfaces:**
- Consumes: `ChallengePreset`, `ChallengeStatus`, `TaskCheck`, `OVRPoint`, `Rank` (SharedTypes), `GameConfig`, `OVREngine.effectiveDay` (Task 1).
- Produces: the 4 `@Model` classes with exact DATA-MODEL §1 fields; `Challenge.activeRules`, `DayLog.checksTotal`, `DayLog.isChecked(_:)`, `PlayerState.displayedOVR/.rank/.highestRank` used by Tasks 3–5.

- [ ] **Step 1: Write `Challenge.swift`**

```swift
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
```

- [ ] **Step 2: Write `TaskRule.swift`**

```swift
import Foundation
import SwiftData

/// One non-negotiable of a challenge. Daily recurrence is implicit (no field in MVP).
/// Editable until day GameConfig.rulesLockDay, locked after.
@Model
final class TaskRule {
    @Attribute(.unique) var id: UUID
    var title: String
    var iconName: String       // SF Symbol
    var domain: String?        // v1.1 radar — stored from day one, no UI in MVP
    var isActive: Bool         // a disabled rule doesn't count toward the day
    var sortOrder: Int
    var createdAt: Date
    var challenge: Challenge?

    init(id: UUID = UUID(), title: String, iconName: String, domain: String? = nil,
         isActive: Bool = true, sortOrder: Int, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.domain = domain
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 3: Write `DayLog.swift`**

```swift
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
```

- [ ] **Step 4: Write `PlayerState.swift`**

```swift
import Foundation
import SwiftData

/// Singleton (fetch-or-create via GameStore, never two instances).
/// Persists ACROSS challenges — the rank is the identity, the challenge is a means.
/// Never reset.
@Model
final class PlayerState {
    @Attribute(.unique) var id: UUID
    var ovrValue: Double               // 0.0…99.0 — display via displayedOVR (floor)
    var currentStreak: Int             // consecutive 100 % days, updated at each closure
    var bestStreak: Int                // all-time record
    var ovrHistory: [OVRPoint]         // 1 point per day closure + per decay tick (Progression curve)
    var completedChallengesCount: Int
    var highestRankReached: Int        // D6 high-water mark (Rank.rawValue) — NEVER goes down
    var lastDayClosedAt: Date?         // last processed rollover (idempotence + decay idle clock)
    var lastDecayTickAt: Date?
    var createdAt: Date

    init(id: UUID = UUID(), ovrValue: Double, createdAt: Date = .now) {
        self.id = id
        self.ovrValue = ovrValue
        self.currentStreak = 0
        self.bestStreak = 0
        self.ovrHistory = []
        self.completedChallengesCount = 0
        self.highestRankReached = Rank.from(ovr: ovrValue).rawValue
        self.lastDayClosedAt = nil
        self.lastDecayTickAt = nil
        self.createdAt = createdAt
    }
}

extension PlayerState {
    var rank: Rank { Rank.from(ovr: ovrValue) }
    /// Never show an unearned point: floor, not rounding.
    var displayedOVR: Int { Int(ovrValue.rounded(.down)) }
    var highestRank: Rank { Rank(rawValue: highestRankReached) ?? .novice }
}
```

- [ ] **Step 5: Compile-only check**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** TEST BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add FUDO/Core/Models/
git commit -m "feat: SwiftData models — Challenge, TaskRule, DayLog, PlayerState"
```

---

### Task 3: GameStore + store tests

**Files:**
- Create: `FUDO/Core/Services/GameStore.swift`
- Test: `FUDOTests/GameStoreTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces: `RuleDraft(title:iconName:domain:)`; `GameStore` — `init(modelContext:calendar:nowProvider:)`, `player: PlayerState?`, `activeChallenge: Challenge?`, `pendingRankUp: Rank?`, `ensurePlayer(startingOVR:) -> PlayerState`, `checkTask(_:)`, `uncheckTask(_:)`, `processRolloverIfNeeded()`, `startChallenge(preset:durationDays:rules:reminderMinutes:) -> Challenge?` (discardable), `abandonChallenge()`, `consumeRankUp() -> Rank?`, `currentLog() -> DayLog?`. Used verbatim by Tasks 4–5.

- [ ] **Step 1: Write `GameStore.swift`**

```swift
import Foundation
import Observation
import SwiftData

/// Input for creating a challenge's rules at setup.
struct RuleDraft {
    var title: String
    var iconName: String
    var domain: String? = nil
}

/// The SINGLE mutation path between UI and OVREngine. Owns the invariants:
/// singleton PlayerState (fetch-or-create), one `.active` challenge max,
/// (challenge, date) DayLog uniqueness, and the D6 rank-up high-water mark.
/// `calendar` and `nowProvider` are injectable so tests drive a simulated clock.
@MainActor
@Observable
final class GameStore {
    private let modelContext: ModelContext
    private let calendar: Calendar
    private let nowProvider: () -> Date

    private(set) var player: PlayerState?
    private(set) var activeChallenge: Challenge?
    /// D6 — set once per rank, the first time the OVR enters it. Consumed by the rank-up cover.
    private(set) var pendingRankUp: Rank?

    init(modelContext: ModelContext, calendar: Calendar = .current,
         nowProvider: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.player = Self.fetchPlayer(in: modelContext)
        self.activeChallenge = Self.fetchActiveChallenge(in: modelContext)
    }

    private var now: Date { nowProvider() }

    // MARK: - Boot fetches

    private static func fetchPlayer(in context: ModelContext) -> PlayerState? {
        let descriptor = FetchDescriptor<PlayerState>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor))?.first
    }

    private static func fetchActiveChallenge(in context: ModelContext) -> Challenge? {
        // iOS 17 #Predicate can't match a Codable enum; the dataset is a handful of
        // challenges ever, so fetch-all + in-memory filter keeps the model verbatim.
        let descriptor = FetchDescriptor<Challenge>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor))?.first { $0.status == .active }
    }

    /// Fetch-or-create — called by onboarding completion (and DebugSeed). Never two instances.
    @discardableResult
    func ensurePlayer(startingOVR: Double) -> PlayerState {
        if let player { return player }
        let created = PlayerState(ovrValue: startingOVR, createdAt: now)
        created.ovrHistory.append(OVRPoint(date: calendar.startOfDay(for: now), value: startingOVR))
        modelContext.insert(created)
        save()
        player = created
        return created
    }

    // MARK: - Checklist (§3b)

    func checkTask(_ rule: TaskRule) {
        guard let player, let challenge = activeChallenge, rule.isActive,
              let log = currentLog(), !log.isChecked(rule) else { return }   // nothing ever pays twice
        let unchecked = challenge.activeRules.filter { !log.isChecked($0) }.count
        let delta = OVREngine.checkDelta(pool: log.dailyGainPool,
                                         alreadyGained: log.checksTotal,
                                         uncheckedActiveCount: unchecked)
        log.checks.append(TaskCheck(ruleID: rule.id, checkedAt: now, ovrDelta: delta))
        applyOVRChange(delta, to: player)   // applied LIVE — Home and sensei react
        save()
    }

    func uncheckTask(_ rule: TaskRule) {
        guard let player, let log = currentLog(),
              let check = log.checks.first(where: { $0.ruleID == rule.id }) else { return }
        log.checks.removeAll { $0.ruleID == rule.id }
        applyOVRChange(OVREngine.refund(for: check), to: player)   // exact reversal
        save()
    }

    /// Today's OPEN log (effective gameplay day, grace period included).
    func currentLog() -> DayLog? {
        guard let challenge = activeChallenge else { return nil }
        let day = OVREngine.effectiveDay(now: now, calendar: calendar)
        return challenge.dayLogs.first { calendar.isDate($0.date, inSameDayAs: day) && !$0.isClosed }
    }

    // MARK: - Rollover (§3e — idempotent, called on scene-active)

    func processRolloverIfNeeded() {
        guard let player else { return }
        if let challenge = activeChallenge {
            closePastDays(of: challenge, player: player)
            if allDaysClosed(challenge) {
                completeChallenge(challenge, player: player)
            } else {
                ensureTodayLog(for: challenge, player: player)
            }
        }
        if activeChallenge == nil {
            applyDecayIfNeeded(player: player)
        }
        save()
    }

    private func closePastDays(of challenge: Challenge, player: PlayerState) {
        let days = OVREngine.daysToClose(now: now, lastProcessedDay: nil,
                                         challengeStartDay: challenge.startDate, calendar: calendar)
        for (offset, day) in days.enumerated() {
            let dayNumber = offset + 1
            guard dayNumber <= challenge.durationDays else { break }
            if let log = log(for: day, in: challenge) {
                if !log.isClosed { close(log, challenge: challenge, player: player) }
            } else {
                // Day the app never opened: synthetic log, one penalty per missed day,
                // pool frozen on the OVR as it stands after the previous closure (session decision 1).
                let log = DayLog(date: day, dayNumber: dayNumber,
                                 dailyGainPool: OVREngine.dailyGainPool(currentOVR: player.ovrValue))
                log.challenge = challenge
                modelContext.insert(log)
                close(log, challenge: challenge, player: player)
            }
        }
    }

    private func close(_ log: DayLog, challenge: Challenge, player: PlayerState) {
        let activeIDs = Set(challenge.activeRules.map(\.id))
        let checkedIDs = Set(log.checks.map(\.ruleID))
        let isComplete = !activeIDs.isEmpty && activeIDs.subtracting(checkedIDs).isEmpty
        let closure = OVREngine.closeDay(isComplete: isComplete, pool: log.dailyGainPool,
                                         checksTotal: log.checksTotal, currentOVR: player.ovrValue,
                                         currentStreak: player.currentStreak, bestStreak: player.bestStreak)
        log.isComplete = isComplete
        log.isClosed = true
        log.ovrDelta = closure.logDelta
        player.ovrValue = closure.newOVR
        player.currentStreak = closure.newStreak
        player.bestStreak = closure.newBestStreak
        player.ovrHistory.append(OVRPoint(date: log.date, value: player.ovrValue))
        // "Morning after" of the closed day, not wall-clock now: keeps the decay idle
        // clock honest when catching up several missed days at once.
        player.lastDayClosedAt = calendar.date(byAdding: .day, value: 1, to: log.date) ?? now
        raiseRankMarkIfNeeded(player)
    }

    private func allDaysClosed(_ challenge: Challenge) -> Bool {
        challenge.dayLogs.filter(\.isClosed).count >= challenge.durationDays
    }

    private func completeChallenge(_ challenge: Challenge, player: PlayerState) {
        challenge.status = .completed
        challenge.endOVR = player.ovrValue
        player.completedChallengesCount += 1
        activeChallenge = nil
    }

    private func ensureTodayLog(for challenge: Challenge, player: PlayerState) {
        let day = OVREngine.effectiveDay(now: now, calendar: calendar)
        guard day >= calendar.startOfDay(for: challenge.startDate) else { return }
        let dayNumber = challenge.currentDayNumber(now: now, calendar: calendar)
        guard dayNumber <= challenge.durationDays else { return }
        guard log(for: day, in: challenge) == nil else { return }   // (challenge, date) uniqueness
        let log = DayLog(date: day, dayNumber: dayNumber,
                         dailyGainPool: OVREngine.dailyGainPool(currentOVR: player.ovrValue))
        log.challenge = challenge
        modelContext.insert(log)
    }

    private func log(for day: Date, in challenge: Challenge) -> DayLog? {
        challenge.dayLogs.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Decay (§3d — only without an active challenge)

    private func applyDecayIfNeeded(player: PlayerState) {
        guard let idleStart = player.lastDayClosedAt else { return }
        let ticksApplied: Int
        if let lastTick = player.lastDecayTickAt {
            ticksApplied = OVREngine.totalDecayTicks(daysIdle: wholeDays(from: idleStart, to: lastTick))
        } else {
            ticksApplied = 0
        }
        let ticksDue = OVREngine.totalDecayTicks(daysIdle: wholeDays(from: idleStart, to: now)) - ticksApplied
        guard ticksDue > 0 else { return }
        player.ovrValue = OVREngine.decayedOVR(current: player.ovrValue, ticks: ticksDue)
        player.ovrHistory.append(OVRPoint(date: calendar.startOfDay(for: now), value: player.ovrValue))
        player.lastDecayTickAt = now
    }

    private func wholeDays(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from),
                                to: calendar.startOfDay(for: to)).day ?? 0
    }

    // MARK: - Challenge lifecycle

    /// Fails (returns nil) if a challenge is already active, rules are empty,
    /// or the rule count exceeds GameConfig.maxRules.
    @discardableResult
    func startChallenge(preset: ChallengePreset, durationDays: Int,
                        rules: [RuleDraft], reminderMinutes: Int) -> Challenge? {
        guard let player, activeChallenge == nil,
              !rules.isEmpty, rules.count <= GameConfig.maxRules else { return nil }
        let start = OVREngine.effectiveDay(now: now, calendar: calendar)
        let challenge = Challenge(preset: preset, durationDays: durationDays, startDate: start,
                                  reminderMinutes: reminderMinutes, startOVR: player.ovrValue,
                                  createdAt: now)
        modelContext.insert(challenge)
        for (index, draft) in rules.enumerated() {
            let rule = TaskRule(title: draft.title, iconName: draft.iconName,
                                domain: draft.domain, sortOrder: index, createdAt: now)
            rule.challenge = challenge
            modelContext.insert(rule)
        }
        activeChallenge = challenge
        ensureTodayLog(for: challenge, player: player)
        save()
        return challenge
    }

    /// Standard penalty on the current day, streak broken, history kept.
    /// The double destructive confirmation lives in the UI (Settings), not here.
    func abandonChallenge() {
        guard let player, let challenge = activeChallenge else { return }
        let pool = currentLog()?.dailyGainPool ?? OVREngine.dailyGainPool(currentOVR: player.ovrValue)
        let penalty = OVREngine.missedDayPenalty(pool: pool)
        player.ovrValue = max(0, player.ovrValue - penalty)
        player.currentStreak = 0
        player.ovrHistory.append(OVRPoint(date: OVREngine.effectiveDay(now: now, calendar: calendar),
                                          value: player.ovrValue))
        player.lastDayClosedAt = now   // idle clock for decay starts now
        if let log = currentLog() {
            log.isClosed = true
            log.ovrDelta = log.checksTotal - penalty
        }
        challenge.status = .abandoned
        challenge.endOVR = player.ovrValue
        activeChallenge = nil
        save()
    }

    // MARK: - Rank-up (D6)

    /// The store is the ONLY writer of the high-water mark: celebrate once per rank,
    /// raise the mark, and a re-climb after decay never re-celebrates.
    private func raiseRankMarkIfNeeded(_ player: PlayerState) {
        let rank = Rank.from(ovr: player.ovrValue)
        if rank.rawValue > player.highestRankReached {
            pendingRankUp = rank
            player.highestRankReached = rank.rawValue
        }
    }

    func consumeRankUp() -> Rank? {
        defer { pendingRankUp = nil }
        return pendingRankUp
    }

    // MARK: - Plumbing

    private func applyOVRChange(_ delta: Double, to player: PlayerState) {
        player.ovrValue = min(GameConfig.ovrMax, max(0, player.ovrValue + delta))
        raiseRankMarkIfNeeded(player)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            // 100 % local store: a failing save has no user-facing recovery path yet.
            // Surface loudly in DEBUG; SwiftData autosave will retry in release.
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Write `FUDOTests/GameStoreTests.swift`**

```swift
import Foundation
import SwiftData
import Testing
@testable import FUDO

@MainActor
struct GameStoreTests {

    /// Reference-typed clock: the store's nowProvider closure sees every mutation.
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeStore(startingAt now: Date) throws -> (GameStore, Clock) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Challenge.self, TaskRule.self, DayLog.self, PlayerState.self,
            configurations: config)
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
        let newPoints = player.ovrHistory.suffix(from: historyBefore)
        #expect(newPoints.count == 4)
        let values = newPoints.map(\.value)
        #expect(values[1] > values[2] && values[2] > values[3])
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
        let afterAbandon = player.ovrValue           // 61.5 − penalty… still ≥ 60? penalty ≈ 2.47 → 59.02 (Disciple)
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
```

- [ ] **Step 3: Compile-only check**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** TEST BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add FUDO/Core/Services/GameStore.swift FUDOTests/GameStoreTests.swift
git commit -m "feat: GameStore — single mutation path (check, rollover, lifecycle, decay, D6)"
```

---

### Task 4: DebugSeed (engine replay) + seed test

**Files:**
- Create: `FUDO/Core/Services/DebugSeed.swift`
- Test: `FUDOTests/DebugSeedTests.swift`

**Interfaces:**
- Consumes: `GameStore`, `RuleDraft`, `OVREngine`, `OnboardingAnswers` (Tasks 1–3).
- Produces: `DebugSeed.seedIfNeeded(context:now:)` and `DebugSeed.seed(context:now:)` (both `#if DEBUG`), called by Task 5's `FUDOApp.init`.

- [ ] **Step 1: Write `DebugSeed.swift`**

```swift
#if DEBUG
import Foundation
import SwiftData

/// The dataset every screen is built against before onboarding exists:
/// active Monk Mode 30 at day 12, OVR 61 (Ascetic), streak 4, five rules,
/// today 3/5 checked. Pure engine REPLAY — zero hand-written values (session
/// decision 3): 11 simulated days through GameStore, day 7 skipped so the
/// curve shows a real penalty drop and the streak restarts at day 8.
enum DebugSeed {

    /// Base 49 → lands on displayed OVR 61 at day 12 (calibrated, asserted below).
    static let answers = OnboardingAnswers(scrollTime: .underTwoHours,
                                           procrastination: .stoppedLyingToMyself,
                                           struggle: .startStrongThenQuit,
                                           commitment: .very)

    static let rules = [
        RuleDraft(title: "Daily workout", iconName: "figure.strengthtraining.traditional"),
        RuleDraft(title: "Cold shower", iconName: "drop.fill"),
        RuleDraft(title: "Read 30 min", iconName: "book.fill"),
        RuleDraft(title: "Screen time under 1h", iconName: "iphone.slash"),
        RuleDraft(title: "Wake up before 7:00", iconName: "sunrise.fill"),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext, now: Date = .now) {
        let count = (try? context.fetchCount(FetchDescriptor<PlayerState>())) ?? 0
        guard count == 0 else { return }
        seed(context: context, now: now)
    }

    @MainActor
    static func seed(context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        // Anchor on the EFFECTIVE day so seeding at 1 AM real time stays coherent.
        let today = OVREngine.effectiveDay(now: now, calendar: calendar)
        guard let day1 = calendar.date(byAdding: .day, value: -11, to: today) else { return }

        var clock = calendar.date(byAdding: .hour, value: 9, to: day1) ?? day1   // 9:00 AM, clear of grace
        let store = GameStore(modelContext: context, calendar: calendar, nowProvider: { clock })

        store.ensurePlayer(startingOVR: OVREngine.startingOVR(from: answers))
        guard let challenge = store.startChallenge(preset: .monk30, durationDays: 30,
                                                   rules: rules, reminderMinutes: 7 * 60) else { return }

        for day in 1...11 {
            store.processRolloverIfNeeded()
            if day != 7 {   // day 7 stays unchecked → penalty at next rollover, streak broken
                for rule in challenge.activeRules {
                    store.checkTask(rule)
                    clock = clock.addingTimeInterval(7 * 60)   // spread check times for the habit timeline
                }
            }
            if let nextDay = calendar.date(byAdding: .day, value: day, to: day1) {
                clock = calendar.date(byAdding: .hour, value: 9, to: nextDay) ?? clock
            }
        }

        clock = calendar.date(byAdding: .hour, value: 9, to: today) ?? clock     // day 12 = today
        store.processRolloverIfNeeded()
        for rule in challenge.activeRules.prefix(3) {
            store.checkTask(rule)
            clock = clock.addingTimeInterval(7 * 60)
        }

        assert(store.player?.displayedOVR == 61,
               "Seed drifted: OVR \(store.player?.displayedOVR ?? -1) ≠ 61 — recalibrate answers")
        assert(store.player?.currentStreak == 4,
               "Seed drifted: streak \(store.player?.currentStreak ?? -1) ≠ 4")
        assert(challenge.currentDayNumber(now: clock, calendar: calendar) == 12,
               "Seed drifted: day \(challenge.currentDayNumber(now: clock, calendar: calendar)) ≠ 12")
    }
}
#endif
```

- [ ] **Step 2: Write `FUDOTests/DebugSeedTests.swift`**

```swift
import Foundation
import SwiftData
import Testing
@testable import FUDO

@MainActor
struct DebugSeedTests {
    @Test func seedProducesTheCanonicalDataset() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Challenge.self, TaskRule.self, DayLog.self, PlayerState.self,
            configurations: config)
        let context = container.mainContext

        DebugSeed.seed(context: context, now: .now)

        let player = try #require(try context.fetch(FetchDescriptor<PlayerState>()).first)
        #expect(player.displayedOVR == 61)
        #expect(player.rank == .ascetic)
        #expect(player.currentStreak == 4)
        #expect(player.bestStreak == 6)                 // days 1-6 before the day-7 miss

        let challenge = try #require(try context.fetch(FetchDescriptor<Challenge>()).first)
        #expect(challenge.status == .active)
        #expect(challenge.preset == .monk30)
        #expect(challenge.durationDays == 30)
        #expect(challenge.rules.count == 5)
        #expect(challenge.currentDayNumber(now: .now) == 12)

        let today = try #require(challenge.dayLogs.max { $0.dayNumber < $1.dayNumber })
        #expect(today.dayNumber == 12)
        #expect(today.checks.count == 3)
        #expect(!today.isClosed)
        let day7 = try #require(challenge.dayLogs.first { $0.dayNumber == 7 })
        #expect(day7.isClosed && !day7.isComplete)      // the visible drop in the curve

        DebugSeed.seedIfNeeded(context: context, now: .now)   // idempotent
        #expect(((try? context.fetch(FetchDescriptor<PlayerState>())) ?? []).count == 1)
    }
}
```

- [ ] **Step 3: Compile-only check**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** TEST BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add FUDO/Core/Services/DebugSeed.swift FUDOTests/DebugSeedTests.swift
git commit -m "feat: DebugSeed — engine-replay dataset (day 12, OVR 61, streak 4)"
```

---

### Task 5: App wiring (container + store + rollover on scene-active)

**Files:**
- Modify: `FUDO/App/FUDOApp.swift` (whole file below)
- Modify: `FUDO/App/RootView.swift` (whole file below)
- Modify: `FUDO/App/AppState.swift` (comment only — seam is now live)

**Interfaces:**
- Consumes: models (Task 2), `GameStore` (Task 3), `DebugSeed` (Task 4).
- Produces: booting app with a live container, seeded DEBUG data, rollover on every scene-activation, `AppState.hasActiveChallenge` fed by the store.

- [ ] **Step 1: Rewrite `FUDOApp.swift`**

```swift
import SwiftData
import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    private let container: ModelContainer
    @State private var gameStore: GameStore

    init() {
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
        do {
            container = try ModelContainer(
                for: Challenge.self, TaskRule.self, DayLog.self, PlayerState.self)
        } catch {
            // 100 % local app, no fallback store: a boot-time container failure is unrecoverable.
            fatalError("ModelContainer creation failed: \(error)")
        }
        #if DEBUG
        DebugSeed.seedIfNeeded(context: container.mainContext)
        #endif
        _gameStore = State(initialValue: GameStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameStore)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Rewrite `RootView.swift`**

```swift
import SwiftUI

/// Root routing: onboarding → paywall → tabs. Onboarding/paywall are covers (per conventions).
/// With current defaults (onboarding done, entitled) it lands on MainTabView.
/// Every scene activation runs the rollover (grace-period closures, decay) before routing.
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var cover: FudoCover?

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .onboarding: OnboardingPlaceholderView()
                case .paywall: PaywallPlaceholderView()
                default: EmptyView()
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        evaluateRoute()
    }

    private func evaluateRoute() {
        if !appState.hasCompletedOnboarding {
            cover = .onboarding
        } else if !appState.entitlementActive {
            cover = .paywall
        } else {
            cover = nil
        }
    }
}
```

- [ ] **Step 3: Update the seam comment in `AppState.swift`**

Replace the line:

```swift
    var hasActiveChallenge = false      // SEAM (Session 1 GameStore)
```

with:

```swift
    var hasActiveChallenge = false      // fed by GameStore via RootView.refresh() (Session 1)
```

- [ ] **Step 4: Compile-only check (app target this time)**

Run: `xcodebuild build -scheme FUDO -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add FUDO/App/FUDOApp.swift FUDO/App/RootView.swift FUDO/App/AppState.swift
git commit -m "feat: wire ModelContainer + GameStore + rollover on scene-active"
```

---

### Task 6: Full test run (the ONE simulator boot) + notebook

**Files:**
- Modify: `CLAUDE.md` (carnet de notes row)

- [ ] **Step 1: Run the complete suite once**

Pick a simulator: `xcrun simctl list devices available | grep iPhone` — use the first available name.
Run: `xcodebuild test -scheme FUDO -destination 'platform=iOS Simulator,name=<first iPhone>' -quiet`
Expected: `** TEST SUCCEEDED **` — all pre-existing suites (Colors, Typography, Rank, GameConfig, Navigation, DesignConstants, SenseiAssetProvider) plus OVREngineTests, GameStoreTests, DebugSeedTests.

- [ ] **Step 2: Fix any failure and re-run ONLY the failing tests**

Use `-only-testing:FUDOTests/<SuiteName>` to avoid re-running everything. No parallel xcodebuild.

- [ ] **Step 3: Append the carnet row in `CLAUDE.md`**

Replace the placeholder row `| _(vide — première entrée au premier build)_ | |` with:

```markdown
| 2026-07-12 | Session 1 (data layer) : 4 @Model + OVREngine + GameStore + DebugSeed livrés. Décisions : 1 pénalité PAR jour manqué (logs synthétiques au rollover) · `OnboardingAnswers` typée (le barème vit dans les enums) · seed = replay moteur base 49 → OVR 61/streak 4/J12 · `lastDayClosedAt` = lendemain du jour clos (sert d'horloge idle au decay). `#Predicate` iOS 17 ne matche pas un enum Codable → fetch-all + filtre mémoire pour le défi actif. Vérif : build-for-testing par étape, suite complète 1× en fin de session. |
```

(Adjust the `statusRaw` sentence to reflect what was actually needed in Task 3.)

- [ ] **Step 4: Final checkpoint commit — `git status` must end empty**

```bash
git add CLAUDE.md docs/superpowers/plans/2026-07-12-data-layer.md
git commit -m "chore: session checkpoint — data layer + engine + tests green"
git status
```

Expected: `nothing to commit, working tree clean`.
