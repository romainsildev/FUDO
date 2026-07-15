import Foundation
import SwiftData
import Testing
@testable import FUDO

@MainActor
@Suite(.serialized)
struct OnboardingViewModelTests {

    private func makeViewModel() throws -> (OnboardingViewModel, GameStore, OnboardingFlags) {
        // NEVER build a container here — SwiftDataTestSupport owns the single one
        // (iOS 17 multi-container crash, carnet 2026-07-12).
        let context = try SwiftDataTestSupport.freshContainer().mainContext
        let store = GameStore(modelContext: context)
        let flags = OnboardingFlags(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
        return (OnboardingViewModel(store: store, flags: flags), store, flags)
    }

    /// The answers that land on a known base: 40 + 3 + 1 + 1 = 45 before commitment.
    private func answerTheQuiz(_ viewModel: OnboardingViewModel) {
        viewModel.draft.scrollTime = .twoToFourHours       // +3
        viewModel.draft.procrastination = .everyMonth      // +1
        viewModel.draft.struggle = .threeDaysMax           // +1
    }

    // MARK: - Navigation

    @Test func aFreshFunnelOpensOnTheSplashAndBlocksBack() throws {
        let (viewModel, _, _) = try makeViewModel()
        #expect(viewModel.step == .splash)
        viewModel.back()
        #expect(viewModel.step == .splash, "there is nothing behind the splash")
    }

    @Test func theCtaIsDeadUntilTheQuestionIsAnswered() throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.jump(to: .painPoint)
        #expect(viewModel.canAdvance == false)
        viewModel.advance()
        #expect(viewModel.step == .painPoint, "an unanswered question never advances")
        viewModel.draft.pain = .doomscrolling
        #expect(viewModel.canAdvance)
        viewModel.advance()
        #expect(viewModel.step == .scrollHours)
    }

    @Test func theSpamGuardSwallowsTheSecondTap() throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.jump(to: .painPoint)
        viewModel.draft.pain = .doomscrolling
        viewModel.advance()
        viewModel.advance()   // the same finger, 30 ms later
        #expect(viewModel.step == .scrollHours, "a double tap must not skip a screen")
    }

    @Test func goalsNeedAtLeastOneSelection() throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.jump(to: .goals)
        #expect(viewModel.canAdvance == false)
        viewModel.draft.goals = [.leanerBody]
        #expect(viewModel.canAdvance)
    }

    @Test func theWallsRefuseToGoBack() throws {
        let (viewModel, _, _) = try makeViewModel()
        for wall in [OnboardingStep.reflection, .firstCheck, .socialProof, .commitment, .contract] {
            viewModel.jump(to: wall)
            viewModel.back()
            #expect(viewModel.step == wall, "\(wall) is a wall — what he said is said")
        }
    }

    // MARK: - D1: the commitment bonus can only raise the number

    @Test func theDiagnosticShowsTheFloorAndTheCommitmentRaisesIt() throws {
        let (viewModel, _, _) = try makeViewModel()
        answerTheQuiz(viewModel)
        // commitment unanswered → .somewhat (0) → 40 + 5 = 45
        #expect(viewModel.diagnosticOVR == 45)

        viewModel.draft.commitment = .extremely            // +2
        #expect(viewModel.diagnosticOVR == 47, "the commitment bonus lifts the floor, never lowers it")
    }

    @Test func noCommitmentAnswerEverLowersTheDiagnostic() throws {
        let (viewModel, _, _) = try makeViewModel()
        answerTheQuiz(viewModel)
        let floor = viewModel.diagnosticOVR
        for commitment in OnboardingAnswers.Commitment.allCases {
            viewModel.draft.commitment = commitment
            #expect(viewModel.diagnosticOVR >= floor)
        }
    }

    @Test func theDiagnosticNeverLeavesTheEngineBand() throws {
        let (viewModel, _, _) = try makeViewModel()
        for scroll in OnboardingAnswers.ScrollTime.allCases {
            for procrastination in OnboardingAnswers.Procrastination.allCases {
                for struggle in OnboardingAnswers.Struggle.allCases {
                    viewModel.draft.scrollTime = scroll
                    viewModel.draft.procrastination = procrastination
                    viewModel.draft.struggle = struggle
                    #expect(viewModel.diagnosticOVR >= GameConfig.baseOVRMin)
                    #expect(viewModel.diagnosticOVR <= GameConfig.baseOVRMax)
                }
            }
        }
    }

    // MARK: - The projection comes from the engine

    @Test func theProjectionIsTheEnginesAndTheRankIsReadFromIt() throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.draft.scrollTime = .twoToFourHours
        viewModel.draft.procrastination = .everyMonth
        viewModel.draft.struggle = .cantEvenStart
        let base = OVREngine.startingOVR(from: viewModel.draft.answers)

        #expect(viewModel.projectedOVR == OVREngine.project(from: base, days: viewModel.setup.durationDays))
        #expect(viewModel.projectedRank == Rank.from(ovr: viewModel.projectedOVR))
        // 44 → 30 perfect days lands in the WARRIOR band, never Master (frame bug).
        #expect(viewModel.projectedRank == .warrior)
    }

    @Test func theProjectionDateIsTheLastDayOfTheChallenge() throws {
        let (viewModel, store, _) = try makeViewModel()
        let expected = store.displayCalendar.date(byAdding: .day, value: viewModel.setup.durationDays - 1,
                                                  to: store.effectiveToday)
        #expect(viewModel.projectionDate == expected)
    }

    // MARK: - Checkpoints

    @Test func signingCreatesThePlayerButNotTheChallenge() throws {
        let (viewModel, store, flags) = try makeViewModel()
        answerTheQuiz(viewModel)
        viewModel.draft.commitment = .extremely
        viewModel.jump(to: .contract)
        viewModel.registerSignature()
        viewModel.signContract()

        #expect(store.player != nil, "the OVR must survive a kill at the paywall")
        #expect(store.activeChallenge == nil, "day 1 must not tick behind the paywall")
        #expect(flags.contract?.durationDays == 30)
        #expect(viewModel.step == .paywall)
    }

    @Test func theSignedOvrIsTheOneTheAnswersProduced() throws {
        let (viewModel, store, flags) = try makeViewModel()
        answerTheQuiz(viewModel)
        viewModel.draft.commitment = .extremely   // 45 + 2 = 47
        viewModel.jump(to: .contract)
        viewModel.registerSignature()
        viewModel.signContract()

        #expect(store.player?.displayedOVR == 47)
        #expect(flags.contract?.startingOVR == 47)
    }

    @Test func theContractCannotBeSignedWithoutAStroke() throws {
        let (viewModel, store, flags) = try makeViewModel()
        viewModel.jump(to: .contract)
        #expect(viewModel.canAdvance == false)
        viewModel.signContract()
        #expect(store.player == nil, "no stroke, no player")
        #expect(flags.contract == nil)
        #expect(viewModel.step == .contract)
    }

    @Test func theLoaderCommitsTheChallengeAfterThePaywall() throws {
        let (viewModel, store, flags) = try makeViewModel()
        answerTheQuiz(viewModel)
        viewModel.jump(to: .contract)
        viewModel.registerSignature()
        viewModel.signContract()
        viewModel.passPaywall()
        #expect(flags.hasCompletedOnboarding, "checkpoint 2")
        #expect(flags.isFullyDone == false, "the hold-lock still holds")

        viewModel.commitChallenge()
        #expect(store.activeChallenge?.durationDays == 30)
        #expect(store.activeChallenge?.startDate == store.effectiveToday, "day 1 is today (D2)")
    }

    @Test func committingTwiceCreatesOneChallenge() throws {
        // A background/foreground mid-loader replays the .task — it must not
        // start a second challenge.
        let (viewModel, store, _) = try makeViewModel()
        answerTheQuiz(viewModel)
        viewModel.jump(to: .contract)
        viewModel.registerSignature()
        viewModel.signContract()
        viewModel.passPaywall()
        viewModel.commitChallenge()
        let first = store.activeChallenge?.id
        viewModel.commitChallenge()
        #expect(store.activeChallenge?.id == first, "the loader must not mint a second challenge")
    }

    @Test func theCommittedProtocolIsTheOneHeComposed() throws {
        let (viewModel, store, _) = try makeViewModel()
        answerTheQuiz(viewModel)
        let composed = viewModel.setup.enabledRules.map(\.title)
        viewModel.jump(to: .contract)
        viewModel.registerSignature()
        viewModel.signContract()
        viewModel.passPaywall()
        viewModel.commitChallenge()

        let committed = store.activeChallenge?.activeRules.map(\.title) ?? []
        #expect(Set(committed) == Set(composed))
    }

    @Test func finishingOpensTheAppAndBurnsTheDraft() throws {
        let (viewModel, _, flags) = try makeViewModel()
        viewModel.finish()
        #expect(flags.isFullyDone)
        #expect(flags.contract == nil)
    }

    @Test func theWelcomeActNeverRestartsTheDojoClip() throws {
        let (viewModel, _, _) = try makeViewModel()
        // Splash and 01a share the dojo: the tap changes the words, not the scene.
        viewModel.jump(to: .splash)
        #expect(viewModel.welcomeClip == .dojo)
        viewModel.jump(to: .transformation)
        #expect(viewModel.welcomeClip == .dojo)
        viewModel.jump(to: .pain)
        #expect(viewModel.welcomeClip == .phone)
        viewModel.jump(to: .mechanism)
        #expect(viewModel.welcomeClip == .doors)
    }
}
