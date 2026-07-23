import Foundation
import Testing
@testable import FUDO

/// Pure verdict-builder coverage — no SwiftData container (the builder takes
/// primitives on purpose, so day tally / most-failed pick / rank climb are tested
/// without booting a store).
struct ChallengeCompletionSummaryTests {

    private func rule(_ title: String, order: Int, misses: Int) -> RuleMissCount {
        RuleMissCount(title: title, sortOrder: order, misses: misses)
    }

    @Test func tallyCountsCompleteAndMissedDays() {
        let s = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 43, endOVRValue: 76,
            closedDayCompletions: Array(repeating: true, count: 27)
                + Array(repeating: false, count: 3),
            reusedRules: [], ruleMissCounts: [])
        #expect(s.daysComplete == 27)
        #expect(s.daysMissed == 3)
    }

    @Test func missedCountsDaysTheAppNeverOpened() {
        // Only 12 closed logs on a 30-day run — the 18 un-opened days still count missed.
        let s = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 49, endOVRValue: 55,
            closedDayCompletions: Array(repeating: true, count: 10)
                + Array(repeating: false, count: 2),
            reusedRules: [], ruleMissCounts: [])
        #expect(s.daysComplete == 10)
        #expect(s.daysMissed == 20)
    }

    @Test func rankClimbDetectedAcrossBands() {
        let climbed = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 43, endOVRValue: 76,
            closedDayCompletions: [], reusedRules: [], ruleMissCounts: [])
        #expect(climbed.startRank == .novice)
        #expect(climbed.endRank == .warrior)
        #expect(climbed.gainedRank)

        let flat = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 72, endOVRValue: 78,          // both Warrior
            closedDayCompletions: [], reusedRules: [], ruleMissCounts: [])
        #expect(!flat.gainedRank)
        #expect(flat.startRank == .warrior)
        #expect(flat.endRank == .warrior)
    }

    @Test func mostFailedPicksTheHighestMissCount() {
        let s = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 49, endOVRValue: 60,
            closedDayCompletions: [],
            reusedRules: [],
            ruleMissCounts: [rule("Workout", order: 0, misses: 2),
                             rule("Cold shower", order: 1, misses: 9),
                             rule("Read", order: 2, misses: 4)])
        #expect(s.mostFailedRuleTitle == "Cold shower")
    }

    @Test func mostFailedTieBreaksOnEarliestRule() {
        let s = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 49, endOVRValue: 60,
            closedDayCompletions: [],
            reusedRules: [],
            ruleMissCounts: [rule("Workout", order: 0, misses: 5),
                             rule("Cold shower", order: 1, misses: 5)])
        #expect(s.mostFailedRuleTitle == "Workout")   // equal misses → lowest sortOrder
    }

    @Test func mostFailedNilOnAFlawlessRun() {
        let s = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 49, endOVRValue: 82,
            closedDayCompletions: Array(repeating: true, count: 30),
            reusedRules: [],
            ruleMissCounts: [rule("Workout", order: 0, misses: 0),
                             rule("Read", order: 1, misses: 0)])
        #expect(s.mostFailedRuleTitle == nil)
    }

    @Test func ovrIsFlooredAndGainSigned() {
        let up = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 43.9, endOVRValue: 76.2,      // floor, never round
            closedDayCompletions: [], reusedRules: [], ruleMissCounts: [])
        #expect(up.startOVR == 43)
        #expect(up.endOVR == 76)
        #expect(up.ovrGain == 33)

        let down = ChallengeCompletionSummary.make(
            id: .init(), preset: .monk30, durationDays: 30,
            startOVRValue: 60, endOVRValue: 56,
            closedDayCompletions: [], reusedRules: [], ruleMissCounts: [])
        #expect(down.ovrGain == -4)
    }
}
