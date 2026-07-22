import Foundation
import Observation

/// State + side effects for the Settings screen. Keeps every mutation behind the
/// GameStore / NotificationService seams — the view only binds and taps.
@MainActor
@Observable
final class SettingsViewModel {
    private let store: GameStore
    private let prefs: NotificationPreferences

    /// Mirror of the persisted switches so SwiftUI observes them; the setters
    /// write through to UserDefaults and fire the notification side effects.
    var dailyReminderEnabled: Bool
    var eveningRemindersEnabled: Bool
    var rankCelebrationsEnabled: Bool

    /// Minutes-since-midnight of the active challenge's reminder (07:00 default).
    var reminderMinutes: Int

    /// Set true while an auth request / (re)schedule is in flight — the toggle
    /// row shows nothing fancy, but the flag guards against double taps.
    private(set) var isSyncingNotifications = false

    init(store: GameStore, prefs: NotificationPreferences = NotificationPreferences()) {
        self.store = store
        self.prefs = prefs
        self.dailyReminderEnabled = prefs.isEnabled(.dailyReminder)
        self.eveningRemindersEnabled = prefs.isEnabled(.eveningReminders)
        self.rankCelebrationsEnabled = prefs.isEnabled(.rankCelebrations)
        self.reminderMinutes = store.activeChallenge?.reminderMinutes
            ?? ChallengeSetupViewModel.defaultReminderMinutes
    }

    // MARK: - Challenge

    var hasActiveChallenge: Bool { store.activeChallenge != nil }
    var canEditRules: Bool { store.canEditActiveRules }

    /// "day X / Y" for the section footer — nil when no challenge is active.
    var challengeSummary: String? {
        guard let challenge = store.activeChallenge, let day = store.todayNumber else { return nil }
        let name = PresetCatalog.title(for: challenge.preset, days: challenge.durationDays)
        return "\(name) · Day \(day) of \(challenge.durationDays)"
    }

    func abandonChallenge() {
        store.abandonChallenge()
    }

    // MARK: - Reminder time (§DÉFI)

    /// Persist the new reminder time, then reschedule if the daily switch is on.
    func updateReminderMinutes(_ minutes: Int) {
        reminderMinutes = minutes
        store.setReminderMinutes(minutes)
        guard dailyReminderEnabled else { return }
        Task { await NotificationService.scheduleDailyReminder(atMinutes: minutes) }
    }

    // MARK: - Notification switches (§NOTIFICATIONS)

    func setEnabled(_ enabled: Bool, for category: NotificationPreferences.Category) {
        switch category {
        case .dailyReminder: dailyReminderEnabled = enabled
        case .eveningReminders: eveningRemindersEnabled = enabled
        case .rankCelebrations: rankCelebrationsEnabled = enabled
        }
        prefs.setEnabled(enabled, for: category)

        // Only the daily reminder schedules anything today. Turning it on must
        // actually ask for permission and queue a request (the RiteOff lesson:
        // "Allow" that scheduled nothing) — turning it off cancels it.
        guard category == .dailyReminder else { return }
        if enabled {
            Task { await enableDailyReminder() }
        } else {
            NotificationService.cancelDailyReminder()
        }
    }

    private func enableDailyReminder() async {
        isSyncingNotifications = true
        defer { isSyncingNotifications = false }
        let granted = await NotificationService.requestAuthorization()
        guard granted else {
            // Denied → the switch cannot honestly stay on. Reflect the real state.
            dailyReminderEnabled = false
            prefs.setEnabled(false, for: .dailyReminder)
            return
        }
        await NotificationService.scheduleDailyReminder(atMinutes: reminderMinutes)
    }

    // MARK: - Subscription (§SUBSCRIPTION)

    /// TODO(S6): RevenueCat is not wired yet — this is the documented stub. Once
    /// `EntitlementStore` ships, restore maps to `Purchases.shared.restorePurchases`.
    func restorePurchases() {
        // Intentionally a no-op until Session 6. No dead-end UX: the row explains it.
    }

    // MARK: - Data (§DATA)

    /// Wipe everything and hand routing back to onboarding. The caller flips
    /// `AppState.hasCompletedOnboarding` so RootView re-renders the funnel.
    func eraseAllData() {
        store.eraseAllData()
    }

    // MARK: - Version

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
