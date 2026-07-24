import Foundation
import Observation

// MARK: - Value types (Progression-local, no persistence)

/// One point on the OVR curve, carrying its DERIVED day-over-day delta and — when the
/// day maps to a challenge DayLog — whether that day closed complete. Nothing new is
/// persisted: the delta is `value[i] − value[i-1]`, the flag is read off `DayLog.isComplete`.
struct CurvePoint: Identifiable, Equatable {
    let id: Int            // index in the window — a stable id for chart selection
    let date: Date
    let value: Double
    let delta: Double       // vs the previous point (0 for the first)
    let isComplete: Bool?   // nil when the day has no DayLog (decay / pre-challenge / today open)
}

/// A rank's state on the descending path. Discovery is the high-water mark: a rank seen
/// in colour stays discovered even if the OVR later drops back below it.
enum RankNodeState: Equatable { case discovered, current, future }

/// A single node of the rank path — everything the view needs, precomputed.
struct RankNode: Identifiable, Equatable {
    let id: Int             // Rank.rawValue
    let rank: Rank
    let state: RankNodeState
    let name: String        // EN display name
    let subtitle: String    // "reached Jul 4" / "current rank · OVR 47" / "unlocks at OVR 60"
    let reachedDate: Date?   // discovered/current only; nil when unknown (started above the floor)
}

// MARK: - View model

/// One `@Observable` view model for the whole Progression tab. Pure read-only projection
/// over `GameStore` — never mutates, never touches `Date.now` (reads the store's clock so
/// tests stay deterministic). The rank/OVR maths is not duplicated here: it calls the same
/// `Rank`/`PlayerState` accessors the rest of the app uses.
@MainActor
@Observable
final class ProgressionViewModel {
    private let store: GameStore

    init(store: GameStore) { self.store = store }

    private var player: PlayerState? { store.player }
    private var calendar: Calendar { store.displayCalendar }

    /// Forces EN month/day formatting regardless of the device locale (UI is EN-only).
    private static let enLocale = Locale(identifier: "en_US")

    // MARK: Hero

    var displayedOVR: Int { player?.displayedOVR ?? 0 }
    var heroRank: Rank { player?.rank ?? .novice }
    var heroRankName: String { heroRank.displayName }
    /// "Rank 2 of 6" — the view uppercases it.
    var rankOrdinalLabel: String { "Rank \(heroRank.rawValue + 1) of \(Rank.allCases.count)" }

    // MARK: Curve

    /// History windowed to the current run, each point with its derived delta + completeness.
    var curvePoints: [CurvePoint] {
        guard let player else { return [] }
        let window = windowedHistory(player.ovrHistory)
        guard !window.isEmpty else { return [] }
        let completeByDay = completenessByDay()
        return window.enumerated().map { index, point in
            let prev = index > 0 ? window[index - 1].value : point.value
            let day = calendar.startOfDay(for: point.date)
            return CurvePoint(id: index, date: point.date, value: point.value,
                              delta: point.value - prev, isComplete: completeByDay[day])
        }
    }

    /// A real curve needs at least two points; below that the view shows a calm caption.
    var hasCurve: Bool { curvePoints.count >= 2 }

    var curveWindowLabel: String {
        let count = curvePoints.count
        return count >= 2 ? "Last \(count) days" : "Your curve starts on day 1"
    }

    /// Net OVR over the last ≤7 points ("this week"). nil when there isn't enough history.
    var weekNet: Int? {
        let points = curvePoints
        guard points.count >= 2 else { return nil }
        let recent = points.suffix(7)
        guard let first = recent.first, let last = recent.last else { return nil }
        return Int((last.value - first.value).rounded())
    }

    // MARK: Rank path

    /// The six rank nodes, top (Novice) → bottom (Sensei), with state + copy resolved.
    var rankNodes: [RankNode] {
        let current = heroRank
        let highest = player?.highestRank ?? .novice
        return Rank.allCases.map { rank in
            let state: RankNodeState
            if rank == current {
                state = .current
            } else if rank.rawValue <= highest.rawValue {
                state = .discovered           // high-water: stays discovered even after a drop
            } else {
                state = .future
            }
            let reached = state == .future ? nil : reachDate(for: rank)
            return RankNode(id: rank.rawValue, rank: rank, state: state,
                            name: rank.displayName,
                            subtitle: subtitle(for: rank, state: state, reached: reached),
                            reachedDate: reached)
        }
    }

    // MARK: - Derivations

    /// Window = the active challenge's run when there is one, else the full history.
    /// Falls back to the full history if the windowed slice is too thin to draw.
    private func windowedHistory(_ history: [OVRPoint]) -> [OVRPoint] {
        let sorted = history.sorted { $0.date < $1.date }
        guard let challenge = store.activeChallenge else { return sorted }
        let start = calendar.startOfDay(for: challenge.startDate)
        let windowed = sorted.filter { $0.date >= start }
        return windowed.count >= 2 ? windowed : sorted
    }

    /// Completeness of each closed challenge day, keyed by start-of-day — one pass, no per-point fetch.
    private func completenessByDay() -> [Date: Bool] {
        guard let logs = store.activeChallenge?.dayLogs else { return [:] }
        var map: [Date: Bool] = [:]
        for log in logs where log.isClosed {
            map[calendar.startOfDay(for: log.date)] = log.isComplete
        }
        return map
    }

    /// First history date whose value reaches the rank's floor — the high-water crossing.
    private func reachDate(for rank: Rank) -> Date? {
        guard let player else { return nil }
        let sorted = player.ovrHistory.sorted { $0.date < $1.date }
        if let crossing = sorted.first(where: { $0.value >= rank.floorOVR }) {
            return crossing.date
        }
        // Novice floor is 0 (reached at the very first point / player creation); a higher rank
        // with no crossing means the player started above it and we simply don't know when.
        return rank == .novice ? (sorted.first?.date ?? player.createdAt) : nil
    }

    private func subtitle(for rank: Rank, state: RankNodeState, reached: Date?) -> String {
        switch state {
        case .current:
            return "current rank · OVR \(displayedOVR)"
        case .discovered:
            if let reached { return "reached \(Self.shortDate(reached))" }
            return "reached"
        case .future:
            return "unlocks at OVR \(Int(rank.floorOVR))"
        }
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(enLocale))
    }
}
