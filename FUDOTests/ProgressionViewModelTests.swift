import Foundation
import SwiftData
import Testing
@testable import FUDO

/// Pure-projection tests for the Progression view model: rank-node states (incl. the high-water
/// case where the OVR has dropped below a rank already seen), the derived "reached" dates, the
/// curve deltas, and the week-net sign. The VM never touches `Date.now`, so we drive it off a
/// GameStore with an injected clock and craft the player's history directly.
@Suite(.serialized)
@MainActor
struct ProgressionViewModelTests {

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeStore(startingAt now: Date) throws -> (GameStore, Clock) {
        let container = try SwiftDataTestSupport.freshContainer()
        let clock = Clock(now)
        let store = GameStore(modelContext: container.mainContext,
                              calendar: .current, nowProvider: { clock.now })
        return (store, clock)
    }

    private func day(_ d: Int) throws -> Date {
        try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: d, hour: 9)))
    }

    /// A player with a crafted OVR value, history and high-water mark — no challenge running.
    private func makeVM(ovr: Double, highest: Rank, history: [OVRPoint]) throws -> ProgressionViewModel {
        let (store, _) = try makeStore(startingAt: try day(1))
        let player = store.ensurePlayer(startingOVR: ovr)
        player.ovrValue = ovr
        player.highestRankReached = highest.rawValue
        player.ovrHistory = history
        return ProgressionViewModel(store: store)
    }

    // MARK: node states

    @Test func nodeStatesFollowCurrentAndHighWater() throws {
        // OVR 63 → Ascetic is current; high-water Warrior was reached then dropped from.
        let vm = try makeVM(ovr: 63, highest: .warrior, history: [
            OVRPoint(date: try day(1), value: 48),
            OVRPoint(date: try day(2), value: 52),   // Disciple
            OVRPoint(date: try day(3), value: 61),   // Ascetic
            OVRPoint(date: try day(4), value: 71),   // Warrior (peak)
            OVRPoint(date: try day(5), value: 63)    // fell back to Ascetic
        ])
        let states = vm.rankNodes.map(\.state)
        #expect(states == [.discovered, .discovered, .current, .discovered, .future, .future])
        // Warrior stays discovered (colour) even though the OVR dropped below it — high-water.
        #expect(vm.rankNodes[Rank.warrior.rawValue].state == .discovered)
        // Master/Sensei still locked.
        #expect(vm.rankNodes[Rank.master.rawValue].state == .future)
        #expect(vm.rankNodes[Rank.master.rawValue].subtitle == "unlocks at OVR 80")
    }

    // MARK: reached dates

    @Test func reachedDateIsFirstCrossingOfTheRankFloor() throws {
        let d1 = try day(1), d2 = try day(2), d3 = try day(3), d4 = try day(4)
        let vm = try makeVM(ovr: 63, highest: .warrior, history: [
            OVRPoint(date: d1, value: 48),   // Novice
            OVRPoint(date: d2, value: 52),   // first ≥ 50 → Disciple reached
            OVRPoint(date: d3, value: 61),   // first ≥ 60 → Ascetic reached
            OVRPoint(date: d4, value: 63)
        ])
        #expect(vm.rankNodes[Rank.novice.rawValue].reachedDate == d1)    // floor 0 → first point
        #expect(vm.rankNodes[Rank.disciple.rawValue].reachedDate == d2)
        #expect(vm.rankNodes[Rank.ascetic.rawValue].reachedDate == d3)
        // Warrior is discovered (high-water) but the history never crossed 70 → unknown date.
        #expect(vm.rankNodes[Rank.warrior.rawValue].reachedDate == nil)
        #expect(vm.rankNodes[Rank.warrior.rawValue].subtitle == "reached")
        // A future rank exposes no reached date.
        #expect(vm.rankNodes[Rank.sensei.rawValue].reachedDate == nil)
    }

    // MARK: curve deltas

    @Test func curveDeltasAreConsecutiveValueDiffs() throws {
        let vm = try makeVM(ovr: 52, highest: .disciple, history: [
            OVRPoint(date: try day(1), value: 50),
            OVRPoint(date: try day(2), value: 55),
            OVRPoint(date: try day(3), value: 52)
        ])
        let deltas = vm.curvePoints.map(\.delta)
        #expect(deltas.count == 3)
        #expect(deltas[0] == 0)                 // first point has no predecessor
        #expect(abs(deltas[1] - 5) < 1e-9)
        #expect(abs(deltas[2] + 3) < 1e-9)
        #expect(vm.hasCurve)
        #expect(vm.curveWindowLabel == "Last 3 days")
    }

    // MARK: week net

    @Test func weekNetSignsWithTheTrend() throws {
        let up = try makeVM(ovr: 55, highest: .disciple, history: [
            OVRPoint(date: try day(1), value: 50),
            OVRPoint(date: try day(2), value: 55)
        ])
        #expect(up.weekNet == 5)

        let down = try makeVM(ovr: 50, highest: .ascetic, history: [
            OVRPoint(date: try day(1), value: 60),
            OVRPoint(date: try day(2), value: 50)
        ])
        #expect(down.weekNet == -10)
    }

    @Test func thinHistoryHasNoCurveAndNoWeekNet() throws {
        let vm = try makeVM(ovr: 49, highest: .novice, history: [
            OVRPoint(date: try day(1), value: 49)
        ])
        #expect(!vm.hasCurve)
        #expect(vm.weekNet == nil)
        #expect(vm.curvePoints.count == 1)
    }
}
