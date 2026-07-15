import Testing
import Foundation
@testable import FUDO

struct RankTests {
    @Test func sixRanksInOrder() {
        #expect(Rank.allCases == [.novice, .disciple, .ascetic, .warrior, .master, .sensei])
    }

    @Test func everyRankNamesItself() {
        // The ONE source: Progression and the onboarding both read this. A rank
        // that renders empty would ship a blank label, not a crash.
        #expect(Rank.allCases.allSatisfy { !$0.displayName.isEmpty })
        #expect(Set(Rank.allCases.map(\.displayName)).count == Rank.allCases.count)
        #expect(Rank.from(ovr: 78).displayName == "Warrior")
    }

    @Test func fromOVRBoundaries() {
        #expect(Rank.from(ovr: 0) == .novice)
        #expect(Rank.from(ovr: 49.9) == .novice)
        #expect(Rank.from(ovr: 50) == .disciple)
        #expect(Rank.from(ovr: 59.9) == .disciple)
        #expect(Rank.from(ovr: 60) == .ascetic)
        #expect(Rank.from(ovr: 69.9) == .ascetic)
        #expect(Rank.from(ovr: 70) == .warrior)
        #expect(Rank.from(ovr: 79.9) == .warrior)
        #expect(Rank.from(ovr: 80) == .master)
        #expect(Rank.from(ovr: 89.9) == .master)
        #expect(Rank.from(ovr: 90) == .sensei)
        #expect(Rank.from(ovr: 99) == .sensei)
    }

    @Test func floorOVRPerRank() {
        #expect(Rank.novice.floorOVR == 0)
        #expect(Rank.disciple.floorOVR == 50)
        #expect(Rank.ascetic.floorOVR == 60)
        #expect(Rank.warrior.floorOVR == 70)
        #expect(Rank.master.floorOVR == 80)
        #expect(Rank.sensei.floorOVR == 90)
    }

    @Test func taskCheckRoundTrips() throws {
        let original = TaskCheck(ruleID: UUID(), checkedAt: Date(timeIntervalSince1970: 1000), ovrDelta: 0.4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskCheck.self, from: data)
        #expect(decoded == original)
    }
}
