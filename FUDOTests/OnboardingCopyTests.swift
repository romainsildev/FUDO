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
        draft.wakeTime = .sevenToNine
        draft.trainingLoad = .oneToTwo
        draft.focusSpan = .tenToThirty
        draft.quitHistory = .twoToThree
        draft.goals = [.leanerBody, .killScrolling, .harderMindset]
        draft.struggle = .threeDaysMax
        return draft
    }

    private var shock: ShockMath.Result {
        ShockMath.result(age: .young1824, scroll: .fourToSixHours)
    }

    // MARK: - OB 06

    @Test func theFusedLineIsRecutByThePain() {
        // Copy pass 2026-07-16: 'of your life' fused with the wound, ONE line,
        // no number repeated (the giant number sits right above it).
        #expect(OnboardingCopy.shockOfYourLife(pain: .reading)
                == "of your life — that's the books you'll never read.")
        #expect(OnboardingCopy.shockOfYourLife(pain: .trainingConsistently)
                == "of your life — that's the training you never did.")
    }

    @Test func everyPainHasItsOwnFusedLineAndNoneIsEmpty() {
        let lines = Pain.allCases.map { OnboardingCopy.shockOfYourLife(pain: $0) }
        #expect(Set(lines).count == Pain.allCases.count, "each pain must get its own line")
        #expect(lines.allSatisfy { $0.hasPrefix("of your life — ") })
    }

    @Test func theShockLeadIsShortAndNamesTheHorizonAge() {
        let older = ShockMath.result(age: .adult2534, scroll: .twoToFourHours)
        #expect(OnboardingCopy.shockLead(shock: older)
                == "By 40, you'll have scrolled away")
    }

    @Test func thePivotStaysCommitmentFramedNeverPseudoScience() {
        // The brief is explicit: commitment framing, never "studies say".
        // (The 30-day stake paragraph died in the UX pass 2026-07-16.)
        for banned in ["studies", "science", "research", "proven"] {
            #expect(OnboardingCopy.shockPivot.lowercased().contains(banned) == false)
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

    @Test func theEnemyStampComesFromTheStruggle() {
        // Bebas stamp (option A, 2026-07-16): all-caps, his failure mode to his face.
        #expect(OnboardingCopy.enemyStamp(.threeDaysMax) == "YOU QUIT AT DAY 3.")
        #expect(OnboardingCopy.enemyStamp(.startStrongThenQuit) == "YOU QUIT AT WEEK 2.")
        #expect(OnboardingCopy.enemyStamp(.cantEvenStart) == "YOU NEVER START.")
    }

    // MARK: - OB 05 — the display order bends, the enum never does

    @Test func procrastinationDisplayOrderIsWorstFirstAndExhaustive() {
        // "Every day" opens the list (tester batch #1); every case must appear
        // exactly once — a forgotten new case would silently drop an answer.
        #expect(OnboardingAnswers.Procrastination.displayOrder.first == .everyDay)
        #expect(Set(OnboardingAnswers.Procrastination.displayOrder)
                == Set(OnboardingAnswers.Procrastination.allCases))
        #expect(OnboardingAnswers.Procrastination.displayOrder.count
                == OnboardingAnswers.Procrastination.allCases.count)
    }

    // MARK: - The report (v2, batch #2)

    @Test func everyReportRowCarriesADetailForTheAccordion() {
        // Collapsed rows show label + hero value; the tap unfolds gauge +
        // detail. A row without a detail is a dead tap — never ship it.
        let rows = OnboardingCopy.reportRows(draft: draft)
        #expect(rows.count == 7)
        #expect(rows.allSatisfy { $0.detail != nil })
        #expect(rows.map(\.label) == ["THE FIGHT", "SCREEN TIME", "MORNING", "TRAINING",
                                      "FOCUS", "TRACK RECORD", "POTENTIAL"])
    }

    @Test func onlyTheMeasurableSectionsCarryAGauge() {
        // A gauge on a qualitative answer would be an invented comparison
        // (honesty guard): exactly screen time / morning / training / focus.
        let rows = OnboardingCopy.reportRows(draft: draft)
        let gauged = rows.filter { $0.gauge != nil }.map(\.label)
        #expect(gauged == ["SCREEN TIME", "MORNING", "TRAINING", "FOCUS"])
    }

    @Test func theGaugesStayInsideTheBarAndTheUserBarIsHisOwnAnswer() {
        // Every fraction must render (0…1); the screen-time bar reuses the
        // ShockMath hours — ONE mapping, never two.
        let rows = OnboardingCopy.reportRows(draft: draft)
        for gauge in rows.compactMap(\.gauge) {
            for mark in [gauge.you, gauge.average, gauge.target] {
                #expect(mark.fraction >= 0 && mark.fraction <= 1)
                #expect(!mark.valueLabel.isEmpty)
            }
        }
    }

    @Test func theVerdictArrowFollowsEachMetricsOwnDirection() {
        // Less screen time is better, earlier is better, more training/focus is
        // better — the arrow must never flatter the wrong way (batch #3).
        var heavy = draft
        heavy.scrollTime = .sixHoursPlus
        heavy.wakeTime = .afterNine
        heavy.trainingLoad = .zero
        heavy.focusSpan = .underTen
        let heavyVerdicts = OnboardingCopy.reportRows(draft: heavy)
            .compactMap(\.gauge).map(\.youBeatsAverage)
        #expect(heavyVerdicts == [false, false, false, false])

        var light = draft
        light.scrollTime = .underTwoHours
        light.wakeTime = .beforeSix
        light.trainingLoad = .fivePlus
        light.focusSpan = .hourPlus
        let lightVerdicts = OnboardingCopy.reportRows(draft: light)
            .compactMap(\.gauge).map(\.youBeatsAverage)
        #expect(lightVerdicts == [true, true, true, true])
    }

    @Test func theReportClaimsNoPercentileAndNoStudy() {
        // Honesty guard (batch #2, non-negotiable): rounded public averages
        // only — never "top N%", never "studies show".
        let rows = OnboardingCopy.reportRows(draft: draft)
        let strings = rows.flatMap { row -> [String] in
            var lines = [row.label, row.value, row.detail ?? ""]
            if let gauge = row.gauge {
                lines += [gauge.you.valueLabel, gauge.average.valueLabel, gauge.target.valueLabel]
            }
            return lines
        }
        for line in strings {
            for banned in ["top ", "%", "studies", "study", "statistically", "science"] {
                #expect(line.lowercased().contains(banned) == false,
                        "\(line) claims a measurement nobody made")
            }
        }
    }

    // MARK: - OB 11 (Romain 2026-07-16: 60 supersedes D3's 30)

    @Test func theRecommendedPresetIsAlwaysTheSixtyDayStake() {
        // Constant on purpose — the draft never bends the recommendation.
        for struggle in OnboardingAnswers.Struggle.allCases {
            var candidate = draft
            candidate.struggle = struggle
            #expect(OnboardingCopy.recommendedPreset(for: candidate) == .monk60)
        }
    }

    // MARK: - D4 — no invented measurement ships

    @Test func theProofCopyClaimsNoMeasurementWeNeverMade() {
        let shipped = [SocialProofCopy.heroLead + SocialProofCopy.heroAccent,
                       SocialProofCopy.counterLead,
                       SocialProofCopy.trackAverageLabel, SocialProofCopy.trackYouLabel(days: 60),
                       SocialProofCopy.reminderStake, SocialProofCopy.widgetStake]
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
