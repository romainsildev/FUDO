import Testing
@testable import FUDO

struct OnboardingStepTests {

    @Test func progressTotalIsDerivedFromTheEnum() {
        // The bar's total is never hand-numbered: it IS the count of bar-carrying steps.
        #expect(OnboardingStep.progressTotal == OnboardingStep.allCases.filter(\.showsProgress).count)
        // Batch #2 (2026-07-16): +4 habit questions, +1 explainer, on top of
        // the 17 the compose split left.
        #expect(OnboardingStep.progressTotal == 22)
    }

    @Test func welcomeLoadersAndPostPaywallHideTheBar() {
        // The 60-seconds launch beat (batch #3) hides the bar too: it is the
        // starting gun, not a step of the quiz.
        let hidden: [OnboardingStep] = [.splash, .transformation, .pain, .mechanism,
                                        .sixtySeconds,
                                        .loaderAnalysis, .loaderSetup, .paywall,
                                        .notifications, .welcomeDojo, .widgetPromo]
        for step in hidden {
            #expect(step.showsProgress == false, "\(step) must hide the progress bar")
            #expect(step.progressFraction == nil)
        }
    }

    @Test func theContractFillsTheBar() {
        #expect(OnboardingStep.contract.progressIndex == OnboardingStep.progressTotal)
        #expect(OnboardingStep.contract.progressFraction == 1.0)
    }

    @Test func theFirstQuestionOpensTheBar() {
        #expect(OnboardingStep.painPoint.progressIndex == 1)
    }

    @Test func barCarryingStepsAreOrderedAndContiguous() {
        // Guards against a step being filtered out of order after a re-shuffle.
        let indices = OnboardingStep.progressSteps.map(\.rawValue)
        #expect(indices == indices.sorted())
    }

    @Test func backIsOfferedOnQuestionsAndBlockedOnWallsAndReveals() {
        for step in [OnboardingStep.painPoint, .scrollHours, .age, .procrastination,
                     .wakeUp, .training, .focus, .struggle, .attempts,
                     .composeDuration, .composeRules] {
            #expect(step.showsBack, "\(step) must offer back")
        }
        // Walls, loaders, the trio — and the REVEALS (2026-07-16): shock stat,
        // goals, diagnostic, projection and the explainer are one-way by design.
        for step in [OnboardingStep.splash, .sixtySeconds, .shockStat, .goals,
                     .reflection, .diagnostic, .protocolIntro, .projection,
                     .loaderAnalysis, .firstCheck, .socialProof, .commitment,
                     .contract, .paywall, .notifications, .loaderSetup,
                     .welcomeDojo, .widgetPromo] {
            #expect(step.showsBack == false, "\(step) must block back")
        }
    }

    /// The restructure (2026-07-16): quiz → analysis loader → report → reveal
    /// → explainer → duration (11a) → rules (11b) → projection. Locked so a
    /// re-shuffle can't silently undo it — the projection NEEDS the duration
    /// chosen first, and the shock beat keeps its inputs (scroll + age) close.
    @Test func theLoaderAnalyzesBeforeTheReportRevealAndProjectionFollowsCompose() {
        #expect(OnboardingStep.mechanism.next == .sixtySeconds)
        #expect(OnboardingStep.sixtySeconds.next == .painPoint)
        #expect(OnboardingStep.shockStat.next == .wakeUp)
        #expect(OnboardingStep.focus.next == .goals)
        #expect(OnboardingStep.struggle.next == .attempts)
        #expect(OnboardingStep.attempts.next == .reflection)
        #expect(OnboardingStep.reflection.next == .loaderAnalysis)
        #expect(OnboardingStep.loaderAnalysis.next == .report)
        #expect(OnboardingStep.report.next == .diagnostic)
        #expect(OnboardingStep.diagnostic.next == .protocolIntro)
        #expect(OnboardingStep.protocolIntro.next == .composeDuration)
        #expect(OnboardingStep.composeDuration.next == .composeRules)
        #expect(OnboardingStep.composeRules.next == .projection)
    }

    @Test func onlyTheVideoActCrossfades() {
        for step in [OnboardingStep.splash, .transformation, .pain, .mechanism] {
            #expect(step.isWelcome)
        }
        // The launch beat slides in like the quiz — leaving the video IS the launch.
        #expect(OnboardingStep.sixtySeconds.isWelcome == false)
        #expect(OnboardingStep.painPoint.isWelcome == false)
    }

    @Test func nextWalksTheWholeFunnelAndStops() {
        #expect(OnboardingStep.splash.next == .transformation)
        #expect(OnboardingStep.contract.next == .paywall)
        #expect(OnboardingStep.widgetPromo.next == nil)
        #expect(OnboardingStep.splash.previous == nil)
        #expect(OnboardingStep.scrollHours.previous == .painPoint)
    }
}
