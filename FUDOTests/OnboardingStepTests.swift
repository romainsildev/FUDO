import Testing
@testable import FUDO

struct OnboardingStepTests {

    @Test func progressTotalIsDerivedFromTheEnum() {
        // The bar's total is never hand-numbered: it IS the count of bar-carrying steps.
        #expect(OnboardingStep.progressTotal == OnboardingStep.allCases.filter(\.showsProgress).count)
        #expect(OnboardingStep.progressTotal == 16)   // +1: the report (2026-07-16)
    }

    @Test func welcomeLoadersAndPostPaywallHideTheBar() {
        let hidden: [OnboardingStep] = [.splash, .transformation, .pain, .mechanism,
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
                     .struggle, .compose] {
            #expect(step.showsBack, "\(step) must offer back")
        }
        // Walls, loaders, the trio — and the REVEALS (2026-07-16): shock stat,
        // goals, diagnostic and projection are one-way by design.
        for step in [OnboardingStep.splash, .shockStat, .goals, .reflection,
                     .diagnostic, .projection, .loaderAnalysis, .firstCheck,
                     .socialProof, .commitment, .contract, .paywall,
                     .notifications, .loaderSetup, .welcomeDojo, .widgetPromo] {
            #expect(step.showsBack == false, "\(step) must block back")
        }
    }

    /// The restructure (2026-07-16): quiz → analysis loader → report → reveal
    /// → compose → projection. Locked so a re-shuffle can't silently undo it.
    @Test func theLoaderAnalyzesBeforeTheReportRevealAndProjectionFollowsCompose() {
        #expect(OnboardingStep.reflection.next == .loaderAnalysis)
        #expect(OnboardingStep.loaderAnalysis.next == .report)
        #expect(OnboardingStep.report.next == .diagnostic)
        #expect(OnboardingStep.compose.next == .projection)
    }

    @Test func onlyTheVideoActCrossfades() {
        for step in [OnboardingStep.splash, .transformation, .pain, .mechanism] {
            #expect(step.isWelcome)
        }
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
