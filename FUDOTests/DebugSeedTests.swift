import Foundation
import SwiftData
import Testing
@testable import FUDO

@MainActor
struct DebugSeedTests {
    @Test func seedProducesTheCanonicalDataset() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FudoSchema.schema, configurations: config)
        let context = container.mainContext

        DebugSeed.seed(context: context, now: .now)

        let player = try #require(try context.fetch(FetchDescriptor<PlayerState>()).first)
        #expect(player.displayedOVR == 61)
        #expect(player.rank == .ascetic)
        #expect(player.currentStreak == 4)
        #expect(player.bestStreak == 6)                 // days 1-6 before the day-7 miss

        let challenge = try #require(try context.fetch(FetchDescriptor<Challenge>()).first)
        #expect(challenge.status == .active)
        #expect(challenge.preset == .monk30)
        #expect(challenge.durationDays == 30)
        #expect(challenge.rules.count == 5)
        #expect(challenge.currentDayNumber(now: .now) == 12)

        let today = try #require(challenge.dayLogs.max { $0.dayNumber < $1.dayNumber })
        #expect(today.dayNumber == 12)
        #expect(today.checks.count == 3)
        #expect(!today.isClosed)
        let day7 = try #require(challenge.dayLogs.first { $0.dayNumber == 7 })
        #expect(day7.isClosed && !day7.isComplete)      // the visible drop in the curve

        DebugSeed.seedIfNeeded(context: context, now: .now)   // idempotent
        #expect(((try? context.fetch(FetchDescriptor<PlayerState>())) ?? []).count == 1)
    }
}
