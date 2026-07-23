import Foundation

/// The REPORT's display model, gamified cut (design pass 2026-07-23 — sensei
/// hero + 2×2 card grid, low mental load): the raw `OnboardingCopy.ReportRow`s
/// digested into exactly what the screen draws. Derived HERE, from the rows the
/// flow already passes, so the flow container and OnboardingCopy stay untouched.
///
/// Colour grammar (hard rule, never inverted): RED = him today, GREY = the
/// average guy, GREEN = the protocol's target, VERMILION = the product
/// speaking. Every figure on screen is his own answer or a `ReportBenchmarks`
/// number — nothing invented (D4 honesty guard).
struct ReportSummary: Equatable {

    /// One benchmarked domain card: label + his value (the proof of
    /// computation) + the gauge the rail is drawn from. The ▲/▼ badge reads
    /// `gauge.youBeatsAverage` — direction already normalised per metric.
    struct Card: Identifiable, Equatable {
        let label: String
        let icon: String
        let value: String
        let gauge: ReportGauge

        var beatsAverage: Bool { gauge.youBeatsAverage }
        var id: String { label }
    }

    /// His stated fight (THE FIGHT row's value) — read under the sensei.
    let fight: String?
    /// The four benchmarked domains, quiz order.
    let cards: [Card]
    /// TRACK RECORD's pivot line (his own history, product answer) — closing block.
    let trackRecordLine: String?
    /// POTENTIAL's value ("4 — 6 h a day to take back") — closing block.
    let potentialLine: String?

    /// Honest synthesis under the sensei: counted from the cards' own verdicts,
    /// nothing new is claimed.
    var verdictLine: String {
        guard !cards.isEmpty else {
            return "The protocol turns what you told us into a daily score."
        }
        let deficits = cards.filter { !$0.beatsAverage }.count
        if deficits == 0 {
            return "Above the average man on every benchmark."
        }
        return "\(deficits) of \(cards.count) benchmarks below the average man."
    }

    // MARK: - Derivation

    /// Matching is by label — the same key `reportRows` is built on; an unknown
    /// benchmarked label degrades to a generic card instead of crashing the
    /// report, an unknown qualitative one is simply not drawn.
    static func summary(from rows: [OnboardingCopy.ReportRow]) -> ReportSummary {
        var fight: String?
        var cards: [Card] = []
        var trackRecordLine: String?
        var potentialLine: String?

        for row in rows {
            switch row.label {
            case "THE FIGHT":
                fight = row.value
            case "TRACK RECORD":
                trackRecordLine = row.detail
            case "POTENTIAL":
                potentialLine = row.value
            default:
                if let gauge = row.gauge {
                    cards.append(Card(label: row.label, icon: icon(for: row.label),
                                      value: row.value, gauge: gauge))
                }
            }
        }
        return ReportSummary(fight: fight, cards: cards,
                             trackRecordLine: trackRecordLine,
                             potentialLine: potentialLine)
    }

    private static func icon(for label: String) -> String {
        switch label {
        case "SCREEN TIME": return "hourglass"
        case "MORNING": return "sunrise"
        case "TRAINING": return "dumbbell"
        case "FOCUS": return "timer"
        default: return "circle"
        }
    }
}
