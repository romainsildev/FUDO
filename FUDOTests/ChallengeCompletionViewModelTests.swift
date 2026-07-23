import Foundation
import Testing
@testable import FUDO

/// The next-hook derivations — the superior-preset ladder and the "Restart harder"
/// escalation. Pure: the VM needs only a summary (no GameStore).
@MainActor
struct ChallengeCompletionViewModelTests {

    private func summary(days: Int, reused: [RuleDraft] = []) -> ChallengeCompletionSummary {
        ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: days,
            startOVRValue: 49, endOVRValue: 60,
            closedDayCompletions: [], reusedRules: reused, ruleMissCounts: [])
    }

    @Test func superiorPresetClimbsThenCaps() {
        #expect(ChallengeCompletionViewModel(summary: summary(days: 30)).superiorPreset == .monk60)
        #expect(ChallengeCompletionViewModel(summary: summary(days: 60)).superiorPreset == .hardcore90)
        #expect(ChallengeCompletionViewModel(summary: summary(days: 90)).superiorPreset == .monk120)
        #expect(ChallengeCompletionViewModel(summary: summary(days: 120)).superiorPreset == .monk120)
        // A retired 75-day run maps up to the next chip (90).
        #expect(ChallengeCompletionViewModel(summary: summary(days: 75)).superiorPreset == .hardcore90)
    }

    @Test func restartReusesRulesAndAddsUpToTwoFromProtocol() throws {
        let monkCore = [RuleDraft(title: "Daily workout", iconName: "figure.strengthtraining.traditional"),
                        RuleDraft(title: "Cold shower", iconName: "drop.fill"),
                        RuleDraft(title: "Read 30 min", iconName: "book.fill"),
                        RuleDraft(title: "Social media under 1h", iconName: "iphone.slash"),
                        RuleDraft(title: "Wake up before 7:00", iconName: "sunrise.fill")]
        let vm = ChallengeCompletionViewModel(summary: summary(days: 30, reused: monkCore))
        let intent = vm.restartIntent
        let rules = try #require(intent.initialRules)

        #expect(intent.initialPreset == .monk30)                 // same preset — rules survive
        #expect(rules.count == 7)                                // 5 reused + 2 additions
        #expect(Array(rules.prefix(5)).map(\.title) == monkCore.map(\.title))
        // Additions are standard-protocol rules he wasn't running.
        let added = Set(rules.suffix(2).map(\.iconName))
        #expect(added.isSubset(of: ["figure.mind.and.body", "wineglass", "square.and.pencil"]))
    }

    @Test func restartAddsNothingWhenTheSetIsAlreadyFull() throws {
        let eight = (0..<8).map { RuleDraft(title: "Rule \($0)", iconName: "flame.fill") }
        let vm = ChallengeCompletionViewModel(summary: summary(days: 30, reused: eight))
        let rules = try #require(vm.restartIntent.initialRules)
        #expect(rules.count == 8)                                // no room under the cap
    }
}
