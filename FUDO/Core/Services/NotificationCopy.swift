import Foundation

/// EVERY word and identifier of the 6 local notifications, in one place — the
/// ASO/copy-rewrite session edits this file and nothing else. Identifiers are
/// STABLE (they double as the reschedule keys AND the `notification_tapped` id),
/// so renaming a case here is a data migration, not a copy tweak.
///
/// Split from `NotificationService` on purpose: the service schedules, this enum
/// only speaks. Pure primitives in, `String` out — trivially unit-testable.
enum NotificationCopy {

    /// The 6 shipped notifications. `rawValue` is the request identifier stored on
    /// the `UNNotificationRequest` AND echoed in `userInfo` as the analytics id, so
    /// the delegate reports `notification_tapped {id}` with these exact slugs.
    enum Kind: String, CaseIterable {
        case dailyReminder = "daily_reminder"
        case eveningReminder = "evening_reminder"
        case streakDanger = "streak_danger"
        case trialD1 = "trial_d1"
        case decayWarning = "decay_warning"
        case rankUp = "rank_up"

        /// Request identifier == analytics id: one string, never diverging.
        var id: String { rawValue }
    }

    /// `userInfo` keys — the delegate reads the id (analytics) and the optional
    /// deep link (routing) off the tapped notification.
    static let idKey = "fudo.notif.id"
    static let deepLinkKey = "fudo.notif.deepLink"
    static let rankRawKey = "fudo.notif.rankRaw"

    /// Deep-link tokens (only rank-up routes anywhere today).
    static let rankUpShareLink = "rank_up_share"

    // MARK: - Titles

    static func title(for kind: Kind) -> String {
        switch kind {
        case .dailyReminder:   return "FUDO"
        case .eveningReminder: return "Your day isn't done"
        case .streakDanger:    return "Streak in danger"
        case .trialD1:         return "Before you're billed"
        case .decayWarning:    return "Your OVR is rusting"
        case .rankUp:          return "Rank up"
        }
    }

    // MARK: - Bodies

    /// Daily — repeating-safe, no day number (a static repeating body can't say
    /// "Day 12" honestly on day 13).
    static var dailyBody: String { "Your protocol is waiting." }

    /// Evening (20:30) — "3h30 before the penalty" (midnight). Singular at 1.
    static func eveningBody(tasksLeft: Int) -> String {
        let noun = tasksLeft == 1 ? "task" : "tasks"
        return "You have \(tasksLeft) \(noun) left. 3h30 before the penalty."
    }

    /// Streak danger (22:30). Singular at 1.
    static func streakDangerBody(streak: Int) -> String {
        let unit = streak == 1 ? "1-day" : "\(streak)-day"
        return "Your \(unit) streak dies at midnight."
    }

    /// Trial D-1 — billing transparency (always delivered, ignores toggles).
    static var trialD1Body: String { "Your trial ends tomorrow. Keep your OVR climbing?" }

    /// Decay warning — day 7 idle, before the first tick.
    static var decayWarningBody: String { "Your OVR is starting to rust. New challenge?" }

    /// Rank-up — the rank is the story; the tap opens the share card.
    static func rankUpBody(rankName: String) -> String {
        "You hit \(rankName). Tap to grab your card."
    }
}
