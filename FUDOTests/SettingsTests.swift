import Foundation
import SwiftData
import Testing
@testable import FUDO

/// S10 Settings — the two mutations the screen introduces (rule editing on the
/// active challenge, production erase) and the notification-preference store.
/// Serialized + shared container like the other SwiftData suites.
@Suite(.serialized)
@MainActor
struct SettingsTests {

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeStore(startingAt now: Date) throws -> (GameStore, Clock) {
        let container = try SwiftDataTestSupport.freshContainer()
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

    /// Current rules → editable set, preserving ids so the reconcile matches.
    private func edits(from challenge: Challenge) -> [RuleEdit] {
        challenge.rules.sorted { $0.sortOrder < $1.sortOrder }.map {
            RuleEdit(id: $0.id, title: $0.title, iconName: $0.iconName,
                     domain: $0.domain, isEnabled: $0.isActive)
        }
    }

    // MARK: - Edit rules

    @Test func renamePreservesIdAndUpdatesTitle() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        var set = edits(from: challenge)
        let targetID = set[0].id
        set[0].title = "Run 5k"

        #expect(store.editActiveChallengeRules(set))
        let renamed = try #require(challenge.rules.first { $0.id == targetID })
        #expect(renamed.title == "Run 5k")
        #expect(challenge.rules.count == 5)
    }

    @Test func addingARuleGrowsTheActiveSet() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        var set = edits(from: challenge)
        set.append(RuleEdit(id: UUID(), title: "Meditate 10 min",
                            iconName: "figure.mind.and.body"))

        #expect(store.editActiveChallengeRules(set))
        #expect(challenge.rules.count == 6)
        #expect(challenge.activeRules.contains { $0.title == "Meditate 10 min" })
    }

    @Test func removingACheckedRuleRefundsExactly() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let rule = try #require(challenge.activeRules.first)
        let baseline = player.ovrValue

        store.checkTask(rule)
        #expect(player.ovrValue > baseline)

        // Drop that rule from the edited set → it should refund the live check.
        let set = edits(from: challenge).filter { $0.id != rule.id }
        #expect(store.editActiveChallengeRules(set))

        #expect(abs(player.ovrValue - baseline) < 1e-9)
        #expect(challenge.rules.count == 4)
        #expect(store.currentLog()?.checks.contains { $0.ruleID == rule.id } == false)
    }

    @Test func disablingACheckedRuleRefundsButKeepsIt() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let player = try #require(store.player)
        let rule = try #require(challenge.activeRules.first)
        let baseline = player.ovrValue

        store.checkTask(rule)
        var set = edits(from: challenge)
        set[0].isEnabled = false   // sorted order → first active rule

        #expect(store.editActiveChallengeRules(set))
        #expect(abs(player.ovrValue - baseline) < 1e-9)
        #expect(challenge.rules.count == 5)                 // kept, not deleted
        #expect(challenge.activeRules.count == 4)           // dropped from the day
    }

    @Test func editingIsRejectedAfterTheLockDay() throws {
        let (store, clock) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        clock.now = try date(day: GameConfig.rulesLockDay + 2)   // past the lock

        #expect(!store.canEditActiveRules)
        var set = edits(from: challenge)
        set[0].title = "Too late"
        #expect(!store.editActiveChallengeRules(set))
        #expect(challenge.rules.allSatisfy { $0.title != "Too late" })
    }

    @Test func emptyEnabledSetIsRejected() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        let set = edits(from: challenge).map {
            RuleEdit(id: $0.id, title: $0.title, iconName: $0.iconName, isEnabled: false)
        }
        #expect(!store.editActiveChallengeRules(set))
        #expect(challenge.activeRules.count == 5)
    }

    @Test func exceedingTheRuleCapIsRejected() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        let challenge = try startMonk30(store)
        var set = edits(from: challenge)
        while set.count <= GameConfig.maxRules {
            set.append(RuleEdit(id: UUID(), title: "Extra \(set.count)", iconName: "flame.fill"))
        }
        #expect(set.count > GameConfig.maxRules)
        #expect(!store.editActiveChallengeRules(set))
        #expect(challenge.rules.count == 5)
    }

    // MARK: - Erase all data

    @Test func eraseAllDataLeavesAVirginStore() throws {
        let (store, _) = try makeStore(startingAt: try date(day: 1))
        try startMonk30(store)
        #expect(store.player != nil)
        #expect(store.activeChallenge != nil)

        let flags = OnboardingFlags(defaults: isolatedDefaults())
        flags.markFullyCompleted()
        #expect(flags.isFullyDone)

        store.eraseAllData(flags: flags)

        #expect(store.player == nil)
        #expect(store.activeChallenge == nil)
        #expect(!flags.isFullyDone)   // routes back to onboarding
    }

    // MARK: - Notification preferences

    @Test func preferencesDefaultToOnWhenAbsent() {
        let prefs = NotificationPreferences(defaults: isolatedDefaults())
        for category in NotificationPreferences.Category.allCases {
            #expect(prefs.isEnabled(category))   // opt-out: absent key reads ON
        }
    }

    @Test func preferencesPersistAnExplicitOff() {
        let defaults = isolatedDefaults()
        let prefs = NotificationPreferences(defaults: defaults)
        prefs.setEnabled(false, for: .eveningReminders)

        // A fresh reader over the same store sees the persisted value.
        let reread = NotificationPreferences(defaults: defaults)
        #expect(!reread.isEnabled(.eveningReminders))
        #expect(reread.isEnabled(.dailyReminder))   // untouched → still ON
    }

    // MARK: - Helpers

    /// A throwaway UserDefaults domain so preference tests never touch real state.
    private func isolatedDefaults() -> UserDefaults {
        let suite = "settings.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
