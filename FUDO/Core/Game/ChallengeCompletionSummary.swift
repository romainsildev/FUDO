import Foundation

/// The flattened verdict of a finished challenge — the data behind the
/// challenge-complete cover. Pure values (no `@Model`, no GameStore) so the cover
/// renders straight off it and the builder is unit-tested with no SwiftData
/// container. `PlayerState` is deliberately absent: the rank persists across
/// challenges, this struct is only THIS run's story.
struct ChallengeCompletionSummary: Equatable, Identifiable {
    /// The finished challenge's id — the cover's presentation identity.
    let id: UUID
    let preset: ChallengePreset
    let durationDays: Int
    let daysComplete: Int
    let daysMissed: Int
    /// Displayed (floored) OVR the run started and ended at — the "43 → 76".
    let startOVR: Int
    let endOVR: Int
    /// Ranks at the run's endpoints — beat 1 replays start→end when it climbed.
    let startRank: Rank
    let endRank: Rank
    /// The active rules of the finished run, ready to reuse for "Restart harder".
    let reusedRules: [RuleDraft]
    /// Title of the rule missed on the most closed days — cited in the restart
    /// copy. Nil when nothing was ever missed (a flawless run).
    let mostFailedRuleTitle: String?

    /// The run climbed at least one rank — beat 1 plays the sensei evolution.
    var gainedRank: Bool { endRank.rawValue > startRank.rawValue }
    /// Signed OVR moved over the run — "+33" (or negative on a rough run).
    var ovrGain: Int { endOVR - startOVR }
}

/// One active rule's miss tally over a finished challenge — the input the pure
/// builder ranks to pick the "most-failed" rule. `sortOrder` is the tie-break:
/// on an equal miss count, the earliest rule (lowest sortOrder) wins, so the
/// pick is stable regardless of input order.
struct RuleMissCount: Equatable {
    let title: String
    let sortOrder: Int
    let misses: Int
}

extension ChallengeCompletionSummary {
    /// Pure builder — GameStore flattens the `@Model` graph into these primitives,
    /// so the verdict logic (day tally, most-failed pick, rank climb) is covered
    /// without a SwiftData container.
    ///
    /// - `closedDayCompletions`: one flag per CLOSED day log (`true` = 100 %).
    ///   `daysMissed` counts against the FULL span (`durationDays − complete`), so
    ///   a day the app never opened still reads as missed even with no closed log.
    static func make(id: UUID,
                     preset: ChallengePreset,
                     durationDays: Int,
                     startOVRValue: Double,
                     endOVRValue: Double,
                     closedDayCompletions: [Bool],
                     reusedRules: [RuleDraft],
                     ruleMissCounts: [RuleMissCount]) -> ChallengeCompletionSummary {
        let complete = closedDayCompletions.filter { $0 }.count
        let missed = max(0, durationDays - complete)
        let mostFailed = ruleMissCounts
            .filter { $0.misses > 0 }
            .max { lhs, rhs in
                lhs.misses != rhs.misses
                    ? lhs.misses < rhs.misses
                    : lhs.sortOrder > rhs.sortOrder   // tie → earliest rule wins
            }
        return ChallengeCompletionSummary(
            id: id,
            preset: preset,
            durationDays: durationDays,
            daysComplete: complete,
            daysMissed: missed,
            startOVR: OVREngine.displayedOVR(startOVRValue),
            endOVR: OVREngine.displayedOVR(endOVRValue),
            startRank: Rank.from(ovr: startOVRValue),
            endRank: Rank.from(ovr: endOVRValue),
            reusedRules: reusedRules,
            mostFailedRuleTitle: mostFailed?.title)
    }
}
