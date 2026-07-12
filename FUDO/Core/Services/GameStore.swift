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

    // MARK: - Read-only aggregates (Home + flame sheet — DATA-MODEL §Agrégations, no new data)

    /// The effective gameplay day on the store's injected clock — views must use THIS,
    /// never `Date.now`, so grace-period behavior and tests stay coherent.
    var effectiveToday: Date { OVREngine.effectiveDay(now: now, calendar: calendar) }

    /// The store's calendar, exposed so views derive week layouts on the same clock.
    var displayCalendar: Calendar { calendar }

    /// Day number "X" of "day X / Y" for the active challenge, on the store's clock.
    var todayNumber: Int? {
        activeChallenge?.currentDayNumber(now: now, calendar: calendar)
    }

    /// DayLog for a given day across ALL challenges — the flame-sheet week can span
    /// a finished challenge. Fetch-all + in-memory match (same iOS 17 #Predicate
    /// limitation as fetchActiveChallenge; dataset stays tiny).
    func dayLog(on day: Date) -> DayLog? {
        let descriptor = FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext.fetch(descriptor))?
            .first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Σ checks.count over every DayLog of every challenge (flame sheet "total checks").
    var totalChecksAllTime: Int {
        let descriptor = FetchDescriptor<DayLog>()
        return ((try? modelContext.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.checks.count }
    }

    /// Seconds until the current effective day ends — the next grace-period boundary
    /// (2 AM wall clock). Target for the foreground rollover timer; the scene-active
    /// path (RootView.refresh) covers every backgrounded crossing.
    var timeUntilNextRollover: TimeInterval {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: effectiveToday),
              let boundary = calendar.date(byAdding: .hour, value: GameConfig.graceHours, to: nextDay)
        else { return 3600 }   // calendar math failed — retry hourly, rollover is idempotent
        return max(1, boundary.timeIntervalSince(now))
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

#if DEBUG
// Debug-menu hooks (Settings §DEBUG). Same file on purpose: they reach the
// private modelContext, boot fetches and completeChallenge. Never in Release.
extension GameStore {

    /// Empties the whole store, then optionally replays DebugSeed (day 12).
    /// Blank wipe arms `DebugSeed.seedDisabledKey` so the launch auto-seed
    /// doesn't resurrect the data; reseeding disarms it.
    func debugWipe(reseed: Bool) {
        wipeAll(DayLog.self)
        wipeAll(TaskRule.self)
        wipeAll(Challenge.self)
        wipeAll(PlayerState.self)
        save()
        UserDefaults.standard.set(!reseed, forKey: DebugSeed.seedDisabledKey)
        if reseed {
            DebugSeed.seed(context: modelContext)
        }
        // The seed replays through its OWN GameStore instance — re-run the boot
        // fetches so THIS store (the one the UI observes) sees the new world.
        player = Self.fetchPlayer(in: modelContext)
        activeChallenge = Self.fetchActiveChallenge(in: modelContext)
        pendingRankUp = nil
    }

    /// Ends the active challenge as `.completed` right now (no day-log closure —
    /// pure shortcut to reach the challenge-complete state on device).
    func debugCompleteActiveChallenge() {
        guard let player, let challenge = activeChallenge else { return }
        completeChallenge(challenge, player: player)
        player.lastDayClosedAt = now   // idle clock for decay starts now
        save()
    }

    private func wipeAll<T: PersistentModel>(_ type: T.Type) {
        // fetch+delete — ModelContext.delete(model:) batch is unreliable on iOS 17.
        for model in (try? modelContext.fetch(FetchDescriptor<T>())) ?? [] {
            modelContext.delete(model)
        }
    }
}
#endif
