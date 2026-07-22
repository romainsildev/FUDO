import Foundation

/// Every string the funnel RE-CUTS from the answers. Kept out of the views so the
/// copy is testable and lives in one place — a recut that drifts between two
/// screens is how a funnel stops sounding like it listened.
enum OnboardingCopy {

    // MARK: - OB 06 — the math

    /// SHORT and secondary (copy pass 2026-07-16, 45 %): the setup, not the blow.
    /// The giant number is the only strong element on OB 06.
    static func shockLead(shock: ShockMath.Result) -> String {
        "By \(shock.horizonAge), you'll have scrolled away"
    }

    /// The ONE line under the giant number: "of your life" fused with his wound
    /// (OB 02) — one sentence instead of two, no number repeated.
    static func shockOfYourLife(pain: Pain) -> String {
        switch pain {
        case .doomscrolling: return "of your life — that's time you'll never scroll back."
        case .wakingUpEarly: return "of your life — that's the mornings you slept through."
        case .trainingConsistently: return "of your life — that's the training you never did."
        case .reading: return "of your life — that's the books you'll never read."
        case .stayingFocused: return "of your life — that's focus that belonged to someone else."
        }
    }

    /// The Mao comfort pivot (brief, 2026-07-13). Commitment framing, never
    /// "studies say". The 30-day stake paragraph died in the UX pass 2026-07-16
    /// (strict minimum on OB 06).
    static let shockPivot = "Monk mode exists exactly for this."

    // MARK: - OB 09 — the reflection

    /// Up to three goals, in enum order (stable — a Set has none), joined as ONE
    /// sentence. Four selections would read as a shopping list; three reads as a man.
    static func reflectionGoals(_ goals: Set<Goal>, fallback: Pain? = nil) -> String {
        let clauses = Goal.allCases.filter { goals.contains($0) }.prefix(3).map(\.clause)
        guard !clauses.isEmpty else {
            guard let fallback else { return "You want out." }
            return painWant(fallback)
        }
        return "You want \(clauses.joined(separator: ", "))."
    }

    private static func painWant(_ pain: Pain) -> String {
        switch pain {
        case .doomscrolling: return "You want to kill doomscrolling."
        case .wakingUpEarly: return "You want to own your mornings."
        case .trainingConsistently: return "You want to train without missing."
        case .reading: return "You want to read every day."
        case .stayingFocused: return "You want your focus back."
        }
    }

    /// OB 09 beat 2 — the STAMP (Romain 2026-07-16, option A séquencée). Two
    /// Bebas lines: the label, then HIS failure mode named to his face. All-caps
    /// because the display font is the voice here, not the sentence case.
    static let enemyLabel = "YOUR ENEMY:"

    static func enemyStamp(_ struggle: OnboardingAnswers.Struggle) -> String {
        switch struggle {
        case .startStrongThenQuit: return "YOU QUIT AT WEEK 2."
        case .threeDaysMax: return "YOU QUIT AT DAY 3."
        case .cantEvenStart: return "YOU NEVER START."
        }
    }

    /// Beat 3 — one line, the pivot out of the wound.
    static let reflectionClose = "The protocol is built to kill it."

    // MARK: - The analysis loader — orbiting stats

    /// One stat orbiting the analysis loader — his own numbers thrown back at
    /// him while the report "computes".
    struct LoaderStat: Equatable {
        var number: String?
        var label: String
        var emphasis: Bool = false
    }

    /// Personalized from the draft — every value is an answer he gave, never an
    /// invented measurement (D4). Deliberately NO OVR (the reveal belongs to
    /// the diagnostic, right after) and NO duration (he hasn't chosen it yet —
    /// restructure 2026-07-16: the loader now precedes the reveal).
    static func analysisLoaderStats(draft: OnboardingDraft) -> [LoaderStat] {
        var stats: [LoaderStat] = []
        if let scroll = draft.scrollTime {
            stats.append(LoaderStat(number: scroll.optionTitle, label: "scrolled daily"))
        }
        if let pain = draft.pain {
            stats.append(LoaderStat(number: nil, label: "Target: \(pain.optionTitle.lowercased())"))
        }
        if let struggle = draft.struggle {
            stats.append(LoaderStat(number: nil, label: wallLabel(struggle), emphasis: true))
        }
        if !draft.goals.isEmpty {
            stats.append(LoaderStat(number: "\(draft.goals.count)",
                                    label: draft.goals.count == 1 ? "target locked" : "targets locked"))
        }
        return stats
    }

    private static func wallLabel(_ struggle: OnboardingAnswers.Struggle) -> String {
        switch struggle {
        case .startStrongThenQuit: return "Breaking your week-2 wall"
        case .threeDaysMax: return "Breaking your day-3 wall"
        case .cantEvenStart: return "Forcing the first step"
        }
    }

    // MARK: - The report

    /// One section of the report. `value` is the hero figure, `detail` the one
    /// line under it, `gauge` the YOU / AVERAGE / TARGET bars (benchmarked
    /// sections only — a gauge on a qualitative answer would be an invented
    /// comparison, honesty guard).
    struct ReportRow: Equatable {
        let label: String
        let value: String
        var detail: String?
        var gauge: ReportGauge?
    }

    /// The ONE dense screen of the funnel — its job is the synthesis. Every
    /// line is his own answer or his own multiplication (ShockMath); every
    /// benchmark is a public rounded average from `ReportBenchmarks`; nothing
    /// invented (D4 + batch #2 honesty guard). The OVR is deliberately absent:
    /// the reveal comes next.
    ///
    /// Accordion (batch #1, kept in v2): collapsed shows label + hero value,
    /// the tap unfolds gauge + detail. Every row must carry a detail: a fold
    /// with nothing behind it is a dead tap.
    static func reportRows(draft: OnboardingDraft) -> [ReportRow] {
        var rows: [ReportRow] = []
        if let pain = draft.pain {
            rows.append(ReportRow(label: "THE FIGHT", value: pain.optionTitle,
                                  detail: fightDetail(pain)))
        }
        if let scroll = draft.scrollTime {
            var detail = "The hours are yours to reassign."
            if let age = draft.age {
                let shock = ShockMath.result(age: age, scroll: scroll)
                detail = "≈ \(shock.headline) gone by \(shock.horizonAge)"
            }
            rows.append(ReportRow(label: "SCREEN TIME", value: "\(scroll.optionTitle) a day",
                                  detail: detail,
                                  gauge: ReportBenchmarks.screenGauge(scroll: scroll)))
        }
        if let wake = draft.wakeTime {
            rows.append(ReportRow(label: "MORNING", value: morningValue(wake),
                                  detail: morningDetail(wake),
                                  gauge: ReportBenchmarks.wakeGauge(bracket: wake)))
        }
        if let load = draft.trainingLoad {
            rows.append(ReportRow(label: "TRAINING", value: trainingValue(load),
                                  detail: trainingDetail(load),
                                  gauge: ReportBenchmarks.trainingGauge(load: load)))
        }
        if let span = draft.focusSpan {
            rows.append(ReportRow(label: "FOCUS", value: span.optionTitle,
                                  detail: focusDetail(span),
                                  gauge: ReportBenchmarks.focusGauge(span: span)))
        }
        if let history = draft.quitHistory {
            rows.append(ReportRow(label: "TRACK RECORD", value: history.optionTitle,
                                  detail: trackRecordDetail(history)))
        }
        if let scroll = draft.scrollTime {
            rows.append(ReportRow(label: "POTENTIAL",
                                  value: "\(scroll.optionTitle) a day to take back",
                                  detail: "recoverable from day 1"))
        }
        return rows
    }

    private static func morningValue(_ bracket: WakeBracket) -> String {
        bracket == .beforeSix ? "Up before 6" : "Up at \(bracket.optionTitle.lowercased())"
    }

    // Gauge-section details sit in a ~60 % column next to the graph (batch #3):
    // two short lines max, the visual carries the rest.
    private static func morningDetail(_ bracket: WakeBracket) -> String {
        switch bracket {
        case .beforeSix: return "Up before the fight starts. Keep it."
        case .sixToSeven: return "Solid base. The protocol locks it in."
        case .sevenToNine: return "The day starts without you."
        case .afterNine: return "The morning is gone. Day 1 takes it back."
        }
    }

    private static func trainingValue(_ load: TrainingLoad) -> String {
        "\(load.optionTitle) a week"
    }

    private static func trainingDetail(_ load: TrainingLoad) -> String {
        switch load {
        case .zero: return "Zero sessions. Daily reps fix that."
        case .oneToTwo: return "Sometimes isn't a system. Daily is."
        case .threeToFour: return "The habit exists. Make it unbreakable."
        case .fivePlus: return "The body works. Lock the rest to its level."
        }
    }

    private static func focusDetail(_ span: FocusSpan) -> String {
        switch span {
        case .underTen: return "The phone owns your attention. Take it back."
        case .tenToThirty: return "Short leash. Daily reps stretch it."
        case .thirtyToSixty: return "Real focus exists. Make it the default."
        case .hourPlus: return "The focus is there. Aim it at your targets."
        }
    }

    private static func trackRecordDetail(_ history: QuitHistory) -> String {
        switch history {
        case .firstTime: return "First real attempt. No scar tissue — build it right, once."
        case .twoToThree: return "You've quit before. This time the OVR keeps the receipts."
        case .lostCount: return "Quitting is a pattern. Patterns break under a visible score."
        }
    }

    /// Accordion detail under THE FIGHT — his own answer folded open, then the
    /// pivot to the protocol. Product mechanics, never an invented measurement (D4).
    private static func fightDetail(_ pain: Pain) -> String {
        switch pain {
        case .doomscrolling: return "You named it yourself. Every rule points at the feed."
        case .wakingUpEarly: return "You named it yourself. The protocol starts with your mornings."
        case .trainingConsistently: return "You named it yourself. The protocol makes showing up daily."
        case .reading: return "You named it yourself. The protocol books the time back."
        case .stayingFocused: return "You named it yourself. The protocol trains focus daily."
        }
    }


    // MARK: - OB 11 — the recommendation (Romain 2026-07-16: 60 supersedes D3's 30)

    /// Always the 60-day stake — the "Recommended" badge moved to Monk Mode 60
    /// with the 30/60/90/120 chips. NOTE the standing tension with the welcome
    /// hooks and shock screen, which still say "30 days": Romain owns that copy
    /// call. The draft is taken (and ignored) on purpose: the day the rule
    /// changes, this signature doesn't.
    static func recommendedPreset(for draft: OnboardingDraft) -> ChallengePreset { .monk60 }

    // MARK: - Dates

    /// "August 10" — EN-only app, so the locale is pinned and never follows the device.
    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    /// "7:00 AM" — the reminder hour, same pinned locale.
    static func clockTime(minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar(identifier: .gregorian).date(from: components)
            ?? Date(timeIntervalSince1970: 0)
        return formatter.string(from: date)
    }
}

/// The proof strings. D4 (Romain, 2026-07-15): NO invented measurement ships —
/// no App Store rating we haven't earned, no "2× more likely" nobody measured,
/// no "statistically" in front of a number that doesn't exist. What's left says
/// the same thing without claiming a study.
enum SocialProofCopy {
    // OB 15 (batch #6) — the named testimonials are GONE, not pending: invented
    // people with invented OVRs were an App Review exposure (2.3.1), not a
    // placeholder. The honest cut is a blunt non-nominative stat + his own
    // number turned back at him. Zero ratings, zero stars, zero first names,
    // zero unverifiable "our users" claims.
    static let heroLead = "MOST MEN\nARE DONE\nBY "
    static let heroAccent = "DAY 4."
    /// "…signed for 60." — the duration is HIS, injected by the screen.
    static let counterLead = "You just signed for "
    static let frameLine = "No community. No excuses. You against you."

    /// OB 18 — was "you are statistically dead by day 4" (no such statistic exists).
    static let reminderStake = "Without it, most men are done by day 4."

    /// OB 21 — was "Users with the widget are 2× more likely to finish" (unmeasured).
    static let widgetStake = "The widget is the difference between remembering and finishing."
}
