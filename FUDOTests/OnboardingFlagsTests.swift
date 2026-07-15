import Foundation
import Testing
@testable import FUDO

@Suite(.serialized)
struct OnboardingFlagsTests {

    /// Each test owns its own suite name so the real app defaults are never touched.
    private func freshFlags(_ name: String = UUID().uuidString) -> OnboardingFlags {
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return OnboardingFlags(defaults: defaults)
    }

    private func snapshot() -> ContractSnapshot {
        ContractSnapshot(startingOVR: 43, projectedOVR: 78.6,
                         preset: .monk30, durationDays: 30,
                         reminderMinutes: 420,
                         rules: [.init(title: "Cold shower", iconName: "drop.fill")])
    }

    @Test func aFreshInstallStartsTheFunnelAtTheSplash() {
        let flags = freshFlags()
        #expect(flags.hasCompletedOnboarding == false)
        #expect(flags.hasFinishedPostPaywall == false)
        #expect(flags.isFullyDone == false)
        #expect(flags.resumeStep == .splash)
    }

    @Test func aKillAfterTheSignatureResumesAtThePaywallWithTheProtocolIntact() {
        let flags = freshFlags()
        flags.contract = snapshot()

        #expect(flags.resumeStep == .paywall)
        #expect(flags.contract?.durationDays == 30)
        #expect(flags.contract?.rules.first?.title == "Cold shower")
        #expect(flags.isFullyDone == false)
    }

    @Test func aKillAfterThePaywallResumesAtTheNotificationsAndNeverReplaysTheQuiz() {
        let flags = freshFlags()
        flags.contract = snapshot()
        flags.hasCompletedOnboarding = true

        #expect(flags.resumeStep == .notifications)
        #expect(flags.isFullyDone == false, "the hold-lock still blocks the app")
    }

    @Test func theHoldLockOnlyOpensWhenTheTrioIsFinished() {
        let flags = freshFlags()
        flags.hasCompletedOnboarding = true
        #expect(flags.isFullyDone == false)
        flags.hasFinishedPostPaywall = true
        #expect(flags.isFullyDone)
    }

    @Test func finishingClearsTheContractDraft() {
        let flags = freshFlags()
        flags.contract = snapshot()
        flags.markFullyCompleted()
        #expect(flags.isFullyDone)
        #expect(flags.contract == nil, "the draft is disposable once the challenge exists")
    }

    @Test func resetReplaysTheWholeFunnel() {
        let flags = freshFlags()
        flags.markFullyCompleted()
        flags.reset()
        #expect(flags.resumeStep == .splash)
        #expect(flags.isFullyDone == false)
    }

    @Test func resetNeverReArmsTheReviewPrompt() {
        // Replaying the funnel in DEBUG must not ask the user to rate us twice.
        let flags = freshFlags()
        flags.reviewPrompted = true
        flags.reset()
        #expect(flags.reviewPrompted)
    }
}
