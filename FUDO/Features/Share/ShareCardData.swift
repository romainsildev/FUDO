import Foundation

/// Everything a 9:16 share card needs, flattened out of the models so the card
/// view renders from plain values (an `ImageRenderer` runs it off-screen with no
/// GameStore in its environment). Real numbers only — never a hardcoded OVR/day.
struct ShareCardData: Equatable {
    let rank: Rank
    let ovr: Int
    let streak: Int
    /// "Day X" — nil outside an active challenge (rank-up can fire between defis).
    let dayNumber: Int?
    /// "/ Y" — nil outside an active challenge.
    let totalDays: Int?
    let presetTitle: String?
    /// Challenge-end only: the OVR the run started at (the "43" of "43 → 76").
    let startOVR: Int?
    /// Challenge-end only: the OVR the run ended at (the "76").
    let endOVR: Int?
}

extension ShareCardData {
    /// DAILY card — the player's live state, optionally framed by the active
    /// challenge. Nil when there is no player (can't compose a card).
    @MainActor
    static func daily(from store: GameStore) -> ShareCardData? {
        guard let player = store.player else { return nil }
        let challenge = store.activeChallenge
        return ShareCardData(
            rank: player.rank,
            ovr: player.displayedOVR,
            streak: player.currentStreak,
            dayNumber: store.todayNumber,
            totalDays: challenge?.durationDays,
            presetTitle: challenge.map { PresetCatalog.title(for: $0.preset, days: $0.durationDays) },
            startOVR: nil,
            endOVR: nil)
    }

    /// RANK-UP card — celebrates the rank just crossed. The rank is the payload
    /// (D6 high-water mark), the OVR/streak come from the live player.
    @MainActor
    static func rankUp(to rank: Rank, from store: GameStore) -> ShareCardData {
        let player = store.player
        let challenge = store.activeChallenge
        return ShareCardData(
            rank: rank,
            ovr: player?.displayedOVR ?? Int(rank.floorOVR),
            streak: player?.currentStreak ?? 0,
            dayNumber: store.todayNumber,
            totalDays: challenge?.durationDays,
            presetTitle: challenge.map { PresetCatalog.title(for: $0.preset, days: $0.durationDays) },
            startOVR: nil,
            endOVR: nil)
    }

    /// CHALLENGE-END card from the flattened completion summary — the S11 trigger
    /// path. The verdict cover has no live `Challenge`/`PlayerState` to pass (the
    /// challenge is already `.completed` and `activeChallenge` nil), so it builds
    /// the card off the same values the verdict shows. `streak` is unused by the
    /// challenge-end card layout (it leads with the OVR delta), hence 0.
    static func challengeEnd(summary: ChallengeCompletionSummary) -> ShareCardData {
        ShareCardData(
            rank: summary.endRank,
            ovr: summary.endOVR,
            streak: 0,
            dayNumber: summary.durationDays,
            totalDays: summary.durationDays,
            presetTitle: PresetCatalog.title(for: summary.preset, days: summary.durationDays),
            startOVR: summary.startOVR,
            endOVR: summary.endOVR)
    }

    /// CHALLENGE-END card — the delta that makes the clip ("OVR 43 → 76").
    /// Kept for callers holding the live models (previews, future paths).
    @MainActor
    static func challengeEnd(challenge: Challenge, player: PlayerState) -> ShareCardData {
        let endValue = challenge.endOVR ?? player.ovrValue
        let end = OVREngine.displayedOVR(endValue)
        return ShareCardData(
            rank: Rank.from(ovr: endValue),
            ovr: end,
            streak: player.bestStreak,
            dayNumber: challenge.durationDays,
            totalDays: challenge.durationDays,
            presetTitle: PresetCatalog.title(for: challenge.preset, days: challenge.durationDays),
            startOVR: OVREngine.displayedOVR(challenge.startOVR),
            endOVR: end)
    }
}

/// Pure card copy — primitives in, String out, no models. The mapping worth
/// locking with a test (day/preset framing, the delta line, the streak line).
enum ShareCardCopy {
    /// "DAY 12 / 30  ·  MONK MODE 30" while a challenge runs; "30 DAYS · …" for a
    /// finished run (no live day); just the preset (or nil) with no duration.
    static func dayLine(day: Int?, total: Int?, preset: String?) -> String? {
        guard let total else { return preset?.uppercased() }
        let dayPart = day.map { "DAY \($0) / \(total)" } ?? "\(total) DAYS"
        if let preset { return "\(dayPart)  ·  \(preset.uppercased())" }
        return dayPart
    }

    /// The clip's number: "43 → 76".
    static func ovrJourneyLine(start: Int, end: Int) -> String {
        "\(start) → \(end)"
    }

    /// Signed OVR gained over a run — "+33". Non-positive runs stay honest.
    static func ovrGainBadge(start: Int, end: Int) -> String {
        String(format: "%+d", end - start)
    }

    /// "4 DAY STREAK" — singular at 1.
    static func streakLine(_ streak: Int) -> String {
        streak == 1 ? "1 DAY STREAK" : "\(streak) DAY STREAK"
    }
}
