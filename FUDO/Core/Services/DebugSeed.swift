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
