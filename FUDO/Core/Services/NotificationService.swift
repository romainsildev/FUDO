import UserNotifications

/// Local notifications only — zero push, zero server (CLAUDE.md).
///
/// This session wires exactly ONE: the daily reminder. The conditional set
/// (evening nudge, streak in danger, trial D-1, decay, rank-up, 2/day cap) is a
/// later session and will live behind this same service.
///
/// The rule this file exists to enforce: "Allow" must actually schedule. RiteOff
/// shipped permission screens whose grant path called no-op stubs — users said
/// yes and never heard from the app again.
@MainActor
enum NotificationService {
    static let dailyReminderID = "fudo.daily.reminder"

    /// What the user chose. Never throws at the caller: a denial is a normal path,
    /// not an error — and an already-denied user gets `false` with no system prompt,
    /// which the screen must treat exactly like a fresh refusal.
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

    /// The one reminder S5 ships. Repeats daily at the challenge's reminder hour.
    /// Re-adding the same identifier IS the reschedule — pending requests never
    /// accumulate.
    static func scheduleDailyReminder(atMinutes minutes: Int) async {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "FUDO"
        // No day number: a repeating trigger carries static content, so "Day 12"
        // would be a lie by day 13. The conditional-notification session will
        // schedule per-day content instead.
        content.body = "Your protocol is waiting."
        content.sound = .default

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

    #if DEBUG
    /// Device check for the grant path: prints what is actually queued. A screen
    /// that "worked" but scheduled nothing is the exact bug this service exists
    /// to prevent — verify, don't assume.
    static func debugDumpPendingReminders() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let reminders = pending.filter { $0.identifier == dailyReminderID }
        if reminders.isEmpty {
            print("[FUDO] no daily reminder scheduled")
        }
        for request in reminders {
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            print("[FUDO] daily reminder at \(trigger?.dateComponents.hour ?? -1):"
                  + String(format: "%02d", trigger?.dateComponents.minute ?? 0)
                  + " — \"\(request.content.body)\"")
        }
    }
    #endif
}
