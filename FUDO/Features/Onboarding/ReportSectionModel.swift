import Foundation

/// One section of the REPORT, enriched for the visual-first cut (S5d): the raw
/// `OnboardingCopy.ReportRow` plus everything the masterclass screen needs —
/// an SF badge, a verdict tag, and a typed mini-viz. Derived HERE, from the
/// rows the flow already passes, so the flow container and OnboardingCopy stay
/// untouched (S5c works on them in parallel).
///
/// Colour grammar (hard rule, never inverted): RED = him today, GREY = the
/// average guy, GREEN = the protocol's target, VERMILION = the product
/// speaking. The verdict tag carries the colour; the copy stays neutral.
struct ReportSection: Identifiable, Equatable {

    /// The tag's colour role — the view maps it to palette tokens.
    enum Tone: Equatable {
        case good      // positive — he legitimately beats the average
        case bad       // negative — the deficit, spelled out
        case accent    // vermilion — the product's own claim (fight, potential)
        case neutral   // grey — factual, no judgement (clean slate)
    }

    /// 10 pt caps verdict, instant read. `beatsAverage` drives the ▲/▼ next to
    /// the text on benchmarked sections; nil on qualitative ones (no invented
    /// comparison, honesty guard).
    struct Verdict: Equatable {
        let text: String
        let tone: Tone
        var beatsAverage: Bool?
    }

    /// The section's graph. Benchmarked sections draw their `ReportGauge`;
    /// qualitative ones get an honest, number-free visual (dots to fill,
    /// a curve with no axis).
    enum Viz: Equatable {
        case bars(ReportGauge)                     // you / average / target
        case dial(ReportGauge)                     // wake-up hour on a track
        case weekDots(filled: Int, target: Int)    // 7-day training week
        case streakDots                            // the streak still unwritten
        case curve                                 // potential teaser, no OVR
    }

    let label: String
    let icon: String
    let value: String
    let detail: String?
    let verdict: Verdict
    let viz: Viz?

    var id: String { label }

    // MARK: - Derivation

    /// Builds the visual sections from the copy rows. Matching is by label —
    /// the same key `reportRows` is built on; an unknown label degrades to a
    /// plain neutral line instead of crashing the report.
    static func sections(from rows: [OnboardingCopy.ReportRow]) -> [ReportSection] {
        rows.map { section(from: $0) }
    }

    private static func section(from row: OnboardingCopy.ReportRow) -> ReportSection {
        switch row.label {
        case "THE FIGHT":
            return ReportSection(label: row.label, icon: "target",
                                 value: row.value, detail: row.detail,
                                 verdict: Verdict(text: "TARGET LOCKED", tone: .accent),
                                 viz: nil)

        case "SCREEN TIME":
            return benchmarked(row, icon: "hourglass",
                               viz: row.gauge.map(Viz.bars))

        case "MORNING":
            return benchmarked(row, icon: "sunrise",
                               viz: row.gauge.map(Viz.dial))

        case "TRAINING":
            return benchmarked(row, icon: "dumbbell",
                               viz: row.gauge.map { gauge in
                                   let dots = ReportBenchmarks.trainingWeekDots(gauge: gauge)
                                   return .weekDots(filled: dots.filled, target: dots.target)
                               })

        case "FOCUS":
            return benchmarked(row, icon: "timer",
                               viz: row.gauge.map(Viz.bars))

        case "TRACK RECORD":
            return ReportSection(label: row.label, icon: "clock.arrow.circlepath",
                                 value: row.value, detail: row.detail,
                                 verdict: trackRecordVerdict(value: row.value),
                                 viz: .streakDots)

        case "POTENTIAL":
            return ReportSection(label: row.label, icon: "arrow.up.right",
                                 value: row.value, detail: row.detail,
                                 verdict: Verdict(text: "UNTAPPED", tone: .accent),
                                 viz: .curve)

        default:
            return ReportSection(label: row.label, icon: "circle",
                                 value: row.value, detail: row.detail,
                                 verdict: Verdict(text: "ON FILE", tone: .neutral),
                                 viz: row.gauge.map(Viz.bars))
        }
    }

    /// Benchmarked sections share one verdict pair: the direction is already
    /// normalised per metric in `ReportGauge.youBeatsAverage` (less screen time
    /// is better, more training is better) — the tag grades HIM, not the raw
    /// number.
    private static func benchmarked(_ row: OnboardingCopy.ReportRow,
                                    icon: String, viz: Viz?) -> ReportSection {
        let beats = row.gauge?.youBeatsAverage ?? false
        return ReportSection(label: row.label, icon: icon,
                             value: row.value, detail: row.detail,
                             verdict: Verdict(text: beats ? "ABOVE AVERAGE" : "BELOW AVERAGE",
                                              tone: beats ? .good : .bad,
                                              beatsAverage: beats),
                             viz: viz)
    }

    /// TRACK RECORD is qualitative — the verdict reads his own answer back,
    /// matched on the option titles `reportRows` prints. Unknown copy falls
    /// back to neutral instead of inventing a judgement.
    private static func trackRecordVerdict(value: String) -> Verdict {
        switch value {
        case QuitHistory.firstTime.optionTitle:
            return Verdict(text: "CLEAN SLATE", tone: .neutral)
        case QuitHistory.twoToThree.optionTitle:
            return Verdict(text: "KNOWN PATTERN", tone: .bad)
        case QuitHistory.lostCount.optionTitle:
            return Verdict(text: "CHRONIC PATTERN", tone: .bad)
        default:
            return Verdict(text: "ON FILE", tone: .neutral)
        }
    }
}
