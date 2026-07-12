import Foundation
import SwiftData

/// Singleton (fetch-or-create via GameStore, never two instances).
/// Persists ACROSS challenges — the rank is the identity, the challenge is a means.
/// Never reset.
@Model
final class PlayerState {
    @Attribute(.unique) var id: UUID
    var ovrValue: Double               // 0.0…99.0 — display via displayedOVR (floor)
    var currentStreak: Int             // consecutive 100 % days, updated at each closure
    var bestStreak: Int                // all-time record
    var ovrHistory: [OVRPoint]         // 1 point per day closure + per decay tick (Progression curve)
    var completedChallengesCount: Int
    var highestRankReached: Int        // D6 high-water mark (Rank.rawValue) — NEVER goes down
    var lastDayClosedAt: Date?         // last processed rollover (idempotence + decay idle clock)
    var lastDecayTickAt: Date?
    var createdAt: Date

    init(id: UUID = UUID(), ovrValue: Double, createdAt: Date = .now) {
        self.id = id
        self.ovrValue = ovrValue
        self.currentStreak = 0
        self.bestStreak = 0
        self.ovrHistory = []
        self.completedChallengesCount = 0
        self.highestRankReached = Rank.from(ovr: ovrValue).rawValue
        self.lastDayClosedAt = nil
        self.lastDecayTickAt = nil
        self.createdAt = createdAt
    }
}

extension PlayerState {
    var rank: Rank { Rank.from(ovr: ovrValue) }
    /// Never show an unearned point: floor, not rounding.
    var displayedOVR: Int { Int(ovrValue.rounded(.down)) }
    var highestRank: Rank { Rank(rawValue: highestRankReached) ?? .novice }
}
