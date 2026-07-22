import Foundation

/// The three notification category switches (Settings §NOTIFICATIONS), persisted
/// in UserDefaults. Opt-OUT model: an absent key reads as ON, so a fresh install
/// (and everyone who onboarded before this screen existed) starts fully enabled.
///
/// Only `dailyReminder` drives a scheduled request today — it is the one
/// notification S5 ships. `eveningReminders` and `rankCelebrations` persist the
/// user's choice for the conditional-notification session to honour; they store
/// real state, so the toggles are functional, not decorative.
struct NotificationPreferences {
    enum Category: String, CaseIterable, Identifiable {
        case dailyReminder = "settings.notif.dailyReminder"
        case eveningReminders = "settings.notif.eveningReminders"
        case rankCelebrations = "settings.notif.rankCelebrations"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dailyReminder: return "Daily reminder"
            case .eveningReminders: return "Evening nudges"
            case .rankCelebrations: return "Rank & celebrations"
            }
        }

        var subtitle: String {
            switch self {
            case .dailyReminder: return "One prompt at your set time."
            case .eveningReminders: return "A push if the day isn't done yet."
            case .rankCelebrations: return "Rank-ups and finished challenges."
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ category: Category) -> Bool {
        // Absent key → ON (opt-out). `object(forKey:)` distinguishes "never set"
        // from an explicit `false`, which `bool(forKey:)` cannot.
        defaults.object(forKey: category.rawValue) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool, for category: Category) {
        defaults.set(enabled, forKey: category.rawValue)
    }
}
