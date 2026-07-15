import Foundation
import Testing
@testable import FUDO

struct OnboardingCopyTests {

    private var draft: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .trainingConsistently
        draft.scrollTime = .fourToSixHours
        draft.age = .young1824
        draft.procrastination = .everyWeek
        draft.goals = [.leanerBody, .killScrolling, .harderMindset]
        draft.struggle = .threeDaysMax
        return draft
    }

    private var shock: ShockMath.Result {
        ShockMath.result(age: .young1824, scroll: .fourToSixHours)
    }

    // MARK: - OB 06

    @Test func theShockLineIsRecutByThePain() {
        #expect(OnboardingCopy.shockRecut(pain: .trainingConsistently, shock: shock)
                == "That's 1.9 years not spent training.")
        #expect(OnboardingCopy.shockRecut(pain: .reading, shock: shock)
                == "That's 1.9 years of books you'll never read.")
        #expect(OnboardingCopy.shockRecut(pain: .doomscrolling, shock: shock)
                == "That's 1.9 years you will never scroll back.")
    }

    @Test func everyPainHasItsOwnRecutAndNoneIsEmpty() {
        let lines = Pain.allCases.map { OnboardingCopy.shockRecut(pain: $0, shock: shock) }
        #expect(Set(lines).count == Pain.allCases.count, "each pain must get its own line")
        #expect(lines.allSatisfy { $0.contains("1.9 years") })
    }

    @Test func theShockHeadlineNamesTheHorizonAge() {
        let older = ShockMath.result(age: .adult2534, scroll: .twoToFourHours)
        #expect(OnboardingCopy.shockLead(shock: older)
                == "At this pace, by age 40\nyou will have scrolled away")
    }

    @Test func theThirtyDayBeatIsAStakeNotAStudy() {
        // The brief is explicit: commitment framing, never pseudo-science.
        #expect(OnboardingCopy.shockStake.contains("30 days"))
        #expect(OnboardingCopy.shockStake.contains("stake"))
        for banned in ["studies", "science", "research", "proven"] {
            #expect(OnboardingCopy.shockStake.lowercased().contains(banned) == false)
        }
    }

    // MARK: - OB 09

    @Test func theReflectionJoinsUpToThreeGoalsInAnswerOrder() {
        #expect(OnboardingCopy.reflectionGoals(draft.goals)
                == "You want a leaner body, no zombie scrolling, a harder mindset.")
    }

    @Test func theReflectionCapsAtThreeGoals() {
        // Four selected → the sentence stays a sentence, not a list.
        let goals: Set<Goal> = [.leanerBody, .earlyWakeUps, .killScrolling, .readDaily]
        let line = OnboardingCopy.reflectionGoals(goals)
        #expect(line.components(separatedBy: ",").count == 3)
    }

    @Test func withoutGoalsTheReflectionFallsBackOnThePain() {
        #expect(OnboardingCopy.reflectionGoals([], fallback: .doomscrolling)
                == "You want to kill doomscrolling.")
    }

    @Test func theEnemyLineComesFromTheStruggle() {
        #expect(OnboardingCopy.enemyLine(.threeDaysMax) == "Your enemy: 3-day consistency.")
        #expect(OnboardingCopy.enemyLine(.startStrongThenQuit) == "Your enemy: week two.")
        #expect(OnboardingCopy.enemyLine(.cantEvenStart) == "Your enemy: the first step.")
    }

    // MARK: - OB 11 (D3)

    @Test func theRecommendedPresetIsAlwaysTheThirtyDayStake() {
        // Every Act-0 hook promises "30 DAYS." — the recommendation never contradicts it.
        for struggle in OnboardingAnswers.Struggle.allCases {
            var candidate = draft
            candidate.struggle = struggle
            #expect(OnboardingCopy.recommendedPreset(for: candidate) == .monk30)
        }
    }

    // MARK: - D4 — no invented measurement ships

    @Test func theProofCopyClaimsNoMeasurementWeNeverMade() {
        let shipped = [SocialProofCopy.proofTitle, SocialProofCopy.reminderStake,
                       SocialProofCopy.widgetStake]
        for line in shipped {
            for banned in ["statistically", "2×", "4.8", "% of"] {
                #expect(line.contains(banned) == false, "\(line) claims a measurement")
            }
        }
    }

    // MARK: - Dates

    @Test func theProjectionDateIsSpelledOutInEnglish() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        let date = Calendar(identifier: .gregorian).date(from: components) ?? .now
        #expect(OnboardingCopy.longDate(date) == "August 10")
    }

    @Test func theReminderHourReadsAsAClock() {
        #expect(OnboardingCopy.clockTime(minutes: 420) == "7:00 AM")
        #expect(OnboardingCopy.clockTime(minutes: 390) == "6:30 AM")
    }
}
