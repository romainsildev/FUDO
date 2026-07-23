import Foundation
import Observation

/// State + side effects for the Settings screen. Keeps every mutation behind the
/// GameStore / NotificationService seams — the view only binds and taps.
@MainActor
@Observable
final class SettingsViewModel {
    private let store: GameStore
    private let prefs: NotificationPreferences
    /// nil in previews / the test shell (RevenueCat unconfigured there).
    private let entitlements: EntitlementStore?

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

    init(store: GameStore, prefs: NotificationPreferences = NotificationPreferences(),
         entitlements: EntitlementStore? = nil) {
        self.store = store
        self.prefs = prefs
        self.entitlements = entitlements
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

    /// Persist the new reminder time. `setReminderMinutes` saves → the store's single
    /// mutation seam recomputes the whole conditional set (daily/evening/streak) on
    /// the new time — no direct schedule call here.
    func updateReminderMinutes(_ minutes: Int) {
        reminderMinutes = minutes
        store.setReminderMinutes(minutes)
    }

    // MARK: - Notification switches (§NOTIFICATIONS)

    func setEnabled(_ enabled: Bool, for category: NotificationPreferences.Category) {
        switch category {
        case .dailyReminder: dailyReminderEnabled = enabled
        case .eveningReminders: eveningRemindersEnabled = enabled
        case .rankCelebrations: rankCelebrationsEnabled = enabled
        }
        prefs.setEnabled(enabled, for: category)

        switch category {
        case .dailyReminder:
            // Turning it ON must actually ask for permission (RiteOff lesson: an
            // "Allow" that scheduled nothing). OFF just recomputes — the planner
            // drops the daily now that its switch reads false.
            if enabled {
                Task { await enableDailyReminder() }
            } else {
                NotificationService.recompute(from: store)
            }
        case .eveningReminders:
            // Gates evening + streak-danger — recompute picks up the new value.
            NotificationService.recompute(from: store)
        case .rankCelebrations:
            // Gates ONLY the immediate rank-up notification (self-checked at the
            // gain moment). Nothing scheduled ahead, so nothing to recompute.
            break
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
            NotificationService.recompute(from: store)
            return
        }
        NotificationService.recompute(from: store)
    }

    // MARK: - Subscription (§SUBSCRIPTION)

    /// Spinner state for the Restore row — guards double taps too.
    private(set) var isRestoring = false
    /// One-shot outcome surfaced as an alert by the view (nil = nothing to show).
    var restoreMessage: String?

    func restorePurchases() {
        guard !isRestoring else { return }
        guard let entitlements else {
            restoreMessage = "The store isn't reachable right now. Try again later."
            return
        }
        isRestoring = true
        Task {
            defer { isRestoring = false }
            switch await entitlements.restore() {
            case .restored:
                Haptics.success()
                restoreMessage = "Purchases restored. You're in."
            case .nothingToRestore:
                restoreMessage = "No previous purchase found on this Apple ID."
            case .failed(let message):
                restoreMessage = message
            }
        }
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
