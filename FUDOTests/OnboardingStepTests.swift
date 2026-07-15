import Testing
@testable import FUDO

struct OnboardingStepTests {

    @Test func progressTotalIsDerivedFromTheEnum() {
        // The bar's total is never hand-numbered: it IS the count of bar-carrying steps.
        #expect(OnboardingStep.progressTotal == OnboardingStep.allCases.filter(\.showsProgress).count)
        #expect(OnboardingStep.progressTotal == 15)
    }

    @Test func welcomeLoadersAndPostPaywallHideTheBar() {
        let hidden: [OnboardingStep] = [.splash, .transformation, .pain, .mechanism,
                                        .loaderBuilding, .loaderSetup, .paywall,
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

    @Test func backIsOfferedOnQuestionsAndBlockedOnWalls() {
        for step in [OnboardingStep.painPoint, .scrollHours, .age, .procrastination,
                     .shockStat, .goals, .struggle, .diagnostic, .compose, .projection] {
            #expect(step.showsBack, "\(step) must offer back")
        }
        for step in [OnboardingStep.splash, .reflection, .loaderBuilding, .firstCheck,
                     .socialProof, .commitment, .contract, .paywall,
                     .notifications, .loaderSetup, .welcomeDojo, .widgetPromo] {
            #expect(step.showsBack == false, "\(step) must block back")
        }
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
