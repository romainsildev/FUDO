import Foundation

/// One row of a report gauge: a short label, a 0…1 bar fraction, the value
/// spelled out. The view colours them by ROLE (you = red, average = grey,
/// target = green) — the data never carries a colour.
struct ReportGauge: Equatable {
    struct Mark: Equatable {
        let label: String        // "YOU" / "AVERAGE" / "TARGET"
        let fraction: Double     // 0…1 share of the gauge's own scale
        let valueLabel: String   // "4 — 6 h" / "~4h30" / "2 h"
    }

    let you: Mark
    let average: Mark
    let target: Mark
    /// The verdict arrow next to the hero figure (batch #3, visual-first):
    /// computed HERE with the metric's own direction (less screen time is
    /// better, more training is better) — the view only colours it.
    let youBeatsAverage: Bool
}

/// EVERY number the report benchmarks against, in ONE place (batch #2, Romain —
/// honesty guard, non-negotiable):
///
///  - Averages are PUBLIC, ROUNDED figures ("average adult: ~4h30/day screen
///    time"), phrased soberly. No invented precision.
///  - NEVER a made-up percentile ("top 12%" is banned), never "studies show".
///    The position on the gauge does the talking.
///  - Targets are the protocol's own bar, not a claim about the world.
///
/// The views never hardcode a benchmark; they draw what this file computes.
enum ReportBenchmarks {

    // MARK: - Screen time (hours/day) — user hours come from ShockMath (ONE mapping)

    static let screenAverageHours = 4.5    // public, rounded: "~4h30/day"
    static let screenTargetHours = 2.0
    private static let screenScaleHours = 8.0

    static func screenGauge(scroll: OnboardingAnswers.ScrollTime) -> ReportGauge {
        let you = ShockMath.hoursPerDay(scroll)
        return gauge(you: you, youLabel: shortHours(you),
                     average: screenAverageHours, averageLabel: "~4h30",
                     target: screenTargetHours, targetLabel: shortHours(screenTargetHours),
                     scale: screenScaleHours,
                     youBeatsAverage: you <= screenAverageHours)   // less is better
    }

    // MARK: - Morning (wake-up hour) — earlier is better; the bar just shows the hour

    static let wakeAverageHour = 7.0       // public, rounded: "~7:00"
    static let wakeTargetHour = 6.0
    private static let wakeScaleHour = 10.5

    private static func wakeHour(_ bracket: WakeBracket) -> Double {
        switch bracket {
        case .beforeSix: return 5.5
        case .sixToSeven: return 6.5
        case .sevenToNine: return 8.0
        case .afterNine: return 9.5
        }
    }

    static func wakeGauge(bracket: WakeBracket) -> ReportGauge {
        gauge(you: wakeHour(bracket), youLabel: bracket.optionTitle,
              average: wakeAverageHour, averageLabel: "~7:00",
              target: wakeTargetHour, targetLabel: "6:00",
              scale: wakeScaleHour,
              youBeatsAverage: wakeHour(bracket) <= wakeAverageHour)   // earlier is better
    }

    // MARK: - Training (sessions/week)

    static let trainingAverageSessions = 2.0   // public, rounded
    static let trainingTargetSessions = 4.0
    private static let trainingScaleSessions = 6.0

    private static func trainingSessions(_ load: TrainingLoad) -> Double {
        switch load {
        case .zero: return 0
        case .oneToTwo: return 1.5
        case .threeToFour: return 3.5
        case .fivePlus: return 5.5
        }
    }

    static func trainingGauge(load: TrainingLoad) -> ReportGauge {
        gauge(you: trainingSessions(load), youLabel: load.optionTitle,
              average: trainingAverageSessions, averageLabel: "~2",
              target: trainingTargetSessions, targetLabel: "4+",
              scale: trainingScaleSessions,
              youBeatsAverage: trainingSessions(load) >= trainingAverageSessions)   // more is better
    }

    // MARK: - Focus (minutes without the phone)

    static let focusAverageMinutes = 25.0      // public, rounded
    static let focusTargetMinutes = 60.0
    private static let focusScaleMinutes = 80.0

    private static func focusMinutes(_ span: FocusSpan) -> Double {
        switch span {
        case .underTen: return 8
        case .tenToThirty: return 20
        case .thirtyToSixty: return 45
        case .hourPlus: return 70
        }
    }

    static func focusGauge(span: FocusSpan) -> ReportGauge {
        gauge(you: focusMinutes(span), youLabel: span.optionTitle,
              average: focusAverageMinutes, averageLabel: "~25 min",
              target: focusTargetMinutes, targetLabel: "60 min",
              scale: focusScaleMinutes,
              youBeatsAverage: focusMinutes(span) >= focusAverageMinutes)   // more is better
    }

    /// The TRAINING week viz (S5d): his sessions as filled dots, the target as
    /// outlined slots, on a 7-day week. Recovered from the gauge's own fraction
    /// so the mapping lives HERE with the scale it was built on.
    static func trainingWeekDots(gauge: ReportGauge) -> (filled: Int, target: Int) {
        let sessions = Int((gauge.you.fraction * trainingScaleSessions).rounded())
        return (filled: min(max(sessions, 0), 7), target: Int(trainingTargetSessions))
    }

    // MARK: - Assembly

    private static func gauge(you: Double, youLabel: String,
                              average: Double, averageLabel: String,
                              target: Double, targetLabel: String,
                              scale: Double, youBeatsAverage: Bool) -> ReportGauge {
        ReportGauge(you: .init(label: "YOU", fraction: fraction(you, scale: scale),
                               valueLabel: youLabel),
                    average: .init(label: "AVERAGE", fraction: fraction(average, scale: scale),
                                   valueLabel: averageLabel),
                    target: .init(label: "TARGET", fraction: fraction(target, scale: scale),
                                  valueLabel: targetLabel),
                    youBeatsAverage: youBeatsAverage)
    }

    private static func fraction(_ value: Double, scale: Double) -> Double {
        guard scale > 0 else { return 0 }
        return min(max(value / scale, 0), 1)
    }

    /// "2 h" / "4.5 h" — hour labels without trailing noise.
    private static func shortHours(_ hours: Double) -> String {
        hours == hours.rounded() ? "\(Int(hours)) h" : "\((hours * 10).rounded() / 10) h"
    }
}
