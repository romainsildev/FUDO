import UIKit
import UserNotifications

/// Local notifications only — zero push, zero server (CLAUDE.md). The ONE
/// scheduler for all 6 notifications: nothing else queues a `UNNotificationRequest`.
///
/// Two shapes of work live here:
///  - RECOMPUTE (`recompute(from:)`): the conditional per-day set — daily, evening,
///    streak-danger, decay. Rebuilt from scratch on EVERY GameStore mutation (the
///    same seam as `WidgetBridge`), so a check that finishes the day wipes tonight's
///    nudges and a rollover re-arms tomorrow's. The planning is PURE (`Planner`,
///    unit-tested); only the install touches the system.
///  - EVENT-SCHEDULED (`scheduleTrialEndingReminder`, `postRankUpIfBackgrounded`):
///    discrete moments (trial start, a rank crossing) that don't fit "recompute the
///    pending set" — they're queued once, at the moment, and recompute never touches
///    their identifiers.
///
/// The rule this file exists to enforce (RiteOff lesson): "Allow" must actually
/// schedule. A grant path that calls a no-op stub is the bug — never fake a
/// notification we didn't queue.
@MainActor
enum NotificationService {

    // MARK: - Identifiers

    /// Legacy id, kept: OB18's onboarding grant path still calls
    /// `scheduleDailyReminder(atMinutes:)` (a UI file we don't touch), and it uses
    /// THIS id. Recompute reuses the same id for the conditional daily, so the
    /// onboarding placeholder is transparently replaced once a challenge exists.
    static let dailyReminderID = NotificationCopy.Kind.dailyReminder.id

    /// The set recompute OWNS — cleared and rebuilt on every recompute. Trial and
    /// rank-up are deliberately absent: their lifecycles are independent.
    private static let managedIDs: [String] = [
        NotificationCopy.Kind.dailyReminder.id,
        NotificationCopy.Kind.eveningReminder.id,
        NotificationCopy.Kind.streakDanger.id,
        NotificationCopy.Kind.decayWarning.id,
    ]

    // MARK: - Authorization (unchanged from S5)

    /// What the user chose. Never throws at the caller: a denial is a normal path,
    /// not an error — and an already-denied user gets `false` with no system prompt.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Legacy daily (OB18 onboarding grant path only)

    /// Onboarding-only: OB18 requests permission and queues a placeholder daily at
    /// this point, BEFORE the challenge exists. It repeats until `recompute` takes
    /// over at challenge start (same identifier → a clean replace). Every other
    /// caller goes through `recompute`.
    static func scheduleDailyReminder(atMinutes minutes: Int) async {
        cancelDailyReminder()
        guard !isSideEffectsSuppressed else { return }
        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.title(for: .dailyReminder)
        content.body = NotificationCopy.dailyBody
        content.sound = .default
        content.userInfo = [NotificationCopy.idKey: NotificationCopy.Kind.dailyReminder.id]
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }

    // MARK: - Recompute (the conditional set)

    /// Rebuild daily / evening / streak / decay from the live store. Called from
    /// `GameStore.save()` — check, uncheck, rollover, challenge start/end/abandon,
    /// reminder-time change and erase all funnel through here, so the pending set
    /// never drifts from game state. Reads the category switches fresh (opt-out).
    static func recompute(from store: GameStore) {
        let prefs = NotificationPreferences()
        let challenge = store.activeChallenge
        let active = challenge?.activeRules ?? []
        let log = store.currentLog()
        let remaining = active.filter { !(log?.isChecked($0) ?? false) }.count

        let input = Planner.Input(
            now: store.wallClockNow,
            calendar: store.displayCalendar,
            hasActiveChallenge: challenge != nil,
            dayComplete: !active.isEmpty && remaining == 0,
            remainingTasks: remaining,
            streak: store.player?.currentStreak ?? 0,
            reminderMinutes: challenge?.reminderMinutes ?? 0,
            lastDayClosedAt: store.player?.lastDayClosedAt,
            dailyEnabled: prefs.isEnabled(.dailyReminder),
            eveningEnabled: prefs.isEnabled(.eveningReminders))

        install(Planner.plan(input), now: input.now)
    }

    /// Cancel + queue the managed set. FULL no-op under tests/previews (recompute
    /// runs on every `save()`, so touching the system center there would be constant
    /// churn) — the planner is what those suites verify.
    private static func install(_ planned: [Planner.Planned], now: Date) {
        guard !isSideEffectsSuppressed else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: managedIDs)
        for item in planned {
            let interval = max(1, item.fireDate.timeIntervalSince(now))
            let request = UNNotificationRequest(
                identifier: item.kind.id,
                content: item.content(),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
            center.add(request, withCompletionHandler: nil)
        }
    }

    // MARK: - Trial D-1 (event-scheduled at purchase — always delivered)

    /// The paywall promises "we remind you before billing" — this keeps it. Queued
    /// once, at trial start, 24h before the trial ends (day `trialDays - 1`). Ignores
    /// every category toggle (billing transparency is non-negotiable).
    static func scheduleTrialEndingReminder(trialDays: Int) {
        guard !isSideEffectsSuppressed else { return }
        let daysAhead = max(1, trialDays - 1)
        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.title(for: .trialD1)
        content.body = NotificationCopy.trialD1Body
        content.sound = .default
        content.userInfo = [NotificationCopy.idKey: NotificationCopy.Kind.trialD1.id]
        let request = UNNotificationRequest(
            identifier: NotificationCopy.Kind.trialD1.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: Double(daysAhead) * 86_400, repeats: false))
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Rank-up (event-scheduled at the gain — only when not on screen)

    /// Fired the instant a new rank is crossed. Foreground → the `RankUpCover` shows
    /// instead (no notification). Gated by the rank-&-celebrations switch. Tap routes
    /// to the share card (deep link carried in `userInfo`).
    static func postRankUpIfBackgrounded(rankName: String, rankRaw: Int) {
        guard !isSideEffectsSuppressed else { return }
        guard NotificationPreferences().isEnabled(.rankCelebrations) else { return }
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.title(for: .rankUp)
        content.body = NotificationCopy.rankUpBody(rankName: rankName)
        content.sound = .default
        content.userInfo = [
            NotificationCopy.idKey: NotificationCopy.Kind.rankUp.id,
            NotificationCopy.deepLinkKey: NotificationCopy.rankUpShareLink,
            NotificationCopy.rankRawKey: rankRaw,
        ]
        let request = UNNotificationRequest(
            identifier: NotificationCopy.Kind.rankUp.id,
            content: content,
            // Effectively immediate; a 1s interval keeps a valid non-repeating trigger.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// The in-app cover consumed the rank-up: drop any delivered/pending notif for
    /// the same event so Notification Center doesn't keep a stale twin.
    static func cancelRankUp() {
        let center = UNUserNotificationCenter.current()
        let id = NotificationCopy.Kind.rankUp.id
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// Funnel restart / data erase: wipe every FUDO notification, pending and
    /// delivered, so nothing fires for a world that no longer exists.
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        let ids = NotificationCopy.Kind.allCases.map(\.id)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Test/preview guard

    /// Unit tests and Xcode previews run HOSTED in this app; they must never write
    /// real requests. The pure `Planner` is what those suites verify.
    private static var isSideEffectsSuppressed: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    #if DEBUG
    /// Device check: prints the whole pending queue. A screen that "worked" but
    /// scheduled nothing is the exact bug this service exists to prevent.
    static func debugDumpPending() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if pending.isEmpty { print("[FUDO] no notifications scheduled"); return }
        for request in pending.sorted(by: { $0.identifier < $1.identifier }) {
            let when: String
            if let t = request.trigger as? UNTimeIntervalNotificationTrigger {
                when = "in \(Int(t.timeInterval))s"
            } else if let c = request.trigger as? UNCalendarNotificationTrigger {
                when = "at \(c.dateComponents.hour ?? -1):"
                    + String(format: "%02d", c.dateComponents.minute ?? 0)
            } else {
                when = "?"
            }
            print("[FUDO] \(request.identifier) \(when) — \"\(request.content.body)\"")
        }
    }

    /// Back-compat alias for the S5 call site (OB18 debug dump).
    static func debugDumpPendingReminders() async { await debugDumpPending() }
    #endif
}

// MARK: - Pure planner (unit-tested)

extension NotificationService {
    /// Decides WHICH conditional notifications exist and WHEN they fire — no system
    /// calls, all value types in and out. The hard invariants live here:
    ///  - a completed day gets ZERO notifications;
    ///  - the daily is conditional (dropped once today is done);
    ///  - HARD CAP 2/day: daily counts, then evening OR streak (never all three);
    ///  - evening is skipped when the reminder time is after 20:30.
    enum Planner {
        /// 20:30 and 22:30 as minutes-since-midnight.
        static let eveningMinute = 20 * 60 + 30
        static let streakMinute = 22 * 60 + 30
        /// Decay warning fires at noon on the 7th idle day.
        static let decayMinute = 12 * 60

        struct Input {
            var now: Date
            var calendar: Calendar
            var hasActiveChallenge: Bool
            var dayComplete: Bool
            var remainingTasks: Int
            var streak: Int
            var reminderMinutes: Int
            var lastDayClosedAt: Date?
            var dailyEnabled: Bool
            /// Gates BOTH evening and streak-danger (§eveningReminders).
            var eveningEnabled: Bool
        }

        struct Planned: Equatable {
            var kind: NotificationCopy.Kind
            var body: String
            var fireDate: Date

            func content() -> UNMutableNotificationContent {
                let content = UNMutableNotificationContent()
                content.title = NotificationCopy.title(for: kind)
                content.body = body
                content.sound = .default
                content.userInfo = [NotificationCopy.idKey: kind.id]
                return content
            }
        }

        static func plan(_ input: Input) -> [Planned] {
            let cal = input.calendar
            let now = input.now
            let midnight = cal.startOfDay(for: now)

            func today(_ minute: Int) -> Date? {
                cal.date(byAdding: .minute, value: minute, to: midnight)
            }
            func tomorrow(_ minute: Int) -> Date? {
                guard let start = cal.date(byAdding: .day, value: 1, to: midnight) else { return nil }
                return cal.date(byAdding: .minute, value: minute, to: start)
            }

            // No active challenge → the only notification is the day-7 idle nudge.
            guard input.hasActiveChallenge else {
                guard let idle = input.lastDayClosedAt,
                      let day7 = cal.date(byAdding: .day, value: GameConfig.decayStartDays,
                                          to: cal.startOfDay(for: idle)),
                      let fire = cal.date(byAdding: .minute, value: decayMinute, to: day7),
                      fire > now else { return [] }
                return [Planned(kind: .decayWarning,
                                body: NotificationCopy.decayWarningBody, fireDate: fire)]
            }

            // Day already done → ZERO today; the daily only looks to tomorrow.
            if input.dayComplete {
                guard input.dailyEnabled, let fire = tomorrow(input.reminderMinutes) else { return [] }
                return [dailyPlanned(fire)]
            }

            var result: [Planned] = []

            // DAILY — today if the time is still ahead, else tomorrow. Either way it
            // occupies one slot of today's cap (it was, or will be, delivered today).
            if input.dailyEnabled {
                let fire = today(input.reminderMinutes).flatMap { $0 > now ? $0 : nil }
                    ?? tomorrow(input.reminderMinutes)
                if let fire { result.append(dailyPlanned(fire)) }
            }

            // HARD CAP 2/day. Daily on → only ONE of evening/streak may follow.
            var budget = input.dailyEnabled ? 1 : 2
            guard input.eveningEnabled, input.remainingTasks >= 1 else { return result }

            // EVENING (20:30) — skipped entirely if the reminder is after 20:30.
            if input.reminderMinutes <= eveningMinute, budget > 0,
               let fire = today(eveningMinute), fire > now {
                result.append(Planned(kind: .eveningReminder,
                                      body: NotificationCopy.eveningBody(tasksLeft: input.remainingTasks),
                                      fireDate: fire))
                budget -= 1
            }

            // STREAK DANGER (22:30) — only with a live streak to lose.
            if input.streak >= 1, budget > 0,
               let fire = today(streakMinute), fire > now {
                result.append(Planned(kind: .streakDanger,
                                      body: NotificationCopy.streakDangerBody(streak: input.streak),
                                      fireDate: fire))
                budget -= 1
            }

            return result
        }

        private static func dailyPlanned(_ fire: Date) -> Planned {
            Planned(kind: .dailyReminder, body: NotificationCopy.dailyBody, fireDate: fire)
        }
    }
}
