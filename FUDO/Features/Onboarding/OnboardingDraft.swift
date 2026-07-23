import Foundation

/// The ONE thing the user can't hold alone (OB 02). Not an OVR input — it re-cuts
/// the downstream copy (shock line, reflection fallback).
enum Pain: CaseIterable, Equatable {
    case doomscrolling, wakingUpEarly, trainingConsistently, reading, stayingFocused

    var optionTitle: String {
        switch self {
        case .doomscrolling: return "Doomscrolling"
        case .wakingUpEarly: return "Waking up early"
        case .trainingConsistently: return "Training consistently"
        case .reading: return "Reading"
        case .stayingFocused: return "Staying focused"
        }
    }
}

/// Age (OB 04) feeds the shock math only — never the OVR.
/// Tester batch #1 (2026-07-16): a senior bracket joined — the shock math works
/// at any age — so `mature35plus` stops being open-ended.
enum AgeBracket: CaseIterable, Equatable {
    case teen1317, young1824, adult2534, mature35plus, senior55plus

    var optionTitle: String {
        switch self {
        case .teen1317: return "13 — 17"
        case .young1824: return "18 — 24"
        case .adult2534: return "25 — 34"
        case .mature35plus: return "35 — 54"
        case .senior55plus: return "55+"
        }
    }
}

// MARK: - Habit questions (batch #2, 2026-07-16) — report inputs, NEVER the OVR.
// The scale stays in OnboardingAnswers' enums; these four feed the benchmarked
// report sections only (morning / training / focus / track record).

/// "When do you get up?" — the report's MORNING section.
enum WakeBracket: CaseIterable, Equatable {
    case beforeSix, sixToSeven, sevenToNine, afterNine

    var optionTitle: String {
        switch self {
        case .beforeSix: return "Before 6"
        case .sixToSeven: return "6 — 7"
        case .sevenToNine: return "7 — 9"
        case .afterNine: return "After 9"
        }
    }
}

/// "Training sessions per week?" — the report's TRAINING section.
/// `zero`, never `none`: on an Optional<TrainingLoad> the compiler resolves
/// `.none` to nil — the answer would silently vanish instead of being "0".
enum TrainingLoad: CaseIterable, Equatable {
    case zero, oneToTwo, threeToFour, fivePlus

    var optionTitle: String {
        switch self {
        case .zero: return "0"
        case .oneToTwo: return "1 — 2"
        case .threeToFour: return "3 — 4"
        case .fivePlus: return "5+"
        }
    }
}

/// "How long can you focus without your phone?" — the report's FOCUS section.
enum FocusSpan: CaseIterable, Equatable {
    case underTen, tenToThirty, thirtyToSixty, hourPlus

    var optionTitle: String {
        switch self {
        case .underTen: return "Under 10 min"
        case .tenToThirty: return "10 — 30 min"
        case .thirtyToSixty: return "30 — 60 min"
        case .hourPlus: return "1 h+"
        }
    }
}

/// "How many times have you tried and quit?" — the report's TRACK RECORD section.
enum QuitHistory: CaseIterable, Equatable {
    case firstTime, twoToThree, lostCount

    var optionTitle: String {
        switch self {
        case .firstTime: return "First time"
        case .twoToThree: return "2 — 3 times"
        case .lostCount: return "I lost count"
        }
    }
}

/// What he actually wants (OB 07, multi-select). Feeds the reflection only.
/// Batch #12 additions: `doWhatIveWanted` (the acted one) and `moreEnergy`
/// (proposed alongside — Romain arbitrates the copy).
enum Goal: CaseIterable, Equatable {
    case leanerBody, earlyWakeUps, killScrolling, readDaily, harderMindset,
         coldShowers, doWhatIveWanted, moreEnergy

    var optionTitle: String {
        switch self {
        case .leanerBody: return "Leaner, stronger body"
        case .earlyWakeUps: return "Master early wake-ups"
        case .killScrolling: return "Kill zombie scrolling"
        case .readDaily: return "Read every day"
        case .harderMindset: return "Harder mindset"
        case .coldShowers: return "Cold showers"
        case .doWhatIveWanted: return "Do what I've always wanted to do"
        case .moreEnergy: return "More energy, less fog"
        }
    }

    /// The reflection reads as one sentence — "You want a leaner body, no zombie
    /// scrolling, a harder mindset." — so each goal carries its clause form.
    var clause: String {
        switch self {
        case .leanerBody: return "a leaner body"
        case .earlyWakeUps: return "early wake-ups"
        case .killScrolling: return "no zombie scrolling"
        case .readDaily: return "reading every day"
        case .harderMindset: return "a harder mindset"
        case .coldShowers: return "cold showers"
        case .doWhatIveWanted: return "to finally do what you've always wanted"
        case .moreEnergy: return "more energy"
        }
    }

    /// OB 07's display order (batch #12): the options his PREVIOUS answers point
    /// at rise to the top — the heavy scroller reads "Kill zombie scrolling"
    /// first. Stable: score descending, enum order breaking ties, zero
    /// randomness. Only answers given BEFORE the goals screen are read.
    static func displayOrder(for draft: OnboardingDraft) -> [Goal] {
        allCases.enumerated().sorted { lhs, rhs in
            let l = lhs.element.affinity(to: draft)
            let r = rhs.element.affinity(to: draft)
            return l == r ? lhs.offset < rhs.offset : l > r
        }.map(\.element)
    }

    private func affinity(to draft: OnboardingDraft) -> Int {
        switch self {
        case .killScrolling:
            var score = 0
            if draft.pain == .doomscrolling { score += 2 }
            switch draft.scrollTime {
            case .sixHoursPlus: score += 2
            case .fourToSixHours: score += 1
            default: break
            }
            if draft.focusSpan == .underTen { score += 1 }
            return score
        case .earlyWakeUps:
            var score = 0
            if draft.pain == .wakingUpEarly { score += 2 }
            switch draft.wakeTime {
            case .afterNine: score += 2
            case .sevenToNine: score += 1
            default: break
            }
            return score
        case .leanerBody:
            var score = 0
            if draft.pain == .trainingConsistently { score += 2 }
            switch draft.trainingLoad {
            case .zero: score += 2
            case .oneToTwo: score += 1
            default: break
            }
            return score
        case .readDaily:
            return draft.pain == .reading ? 2 : 0
        case .harderMindset:
            switch draft.procrastination {
            case .everyDay: return 2
            case .everyWeek: return 1
            default: return 0
            }
        case .moreEnergy:
            return draft.wakeTime == .afterNine ? 1 : 0
        case .coldShowers, .doWhatIveWanted:
            return 0
        }
    }
}

// MARK: - Option titles for the Core answer enums
//
// The scale lives in Core/Game/OnboardingAnswers.swift; the words live HERE.
// Core never learns UI copy, and the funnel never re-declares the points.

extension OnboardingAnswers.ScrollTime {
    var optionTitle: String {
        switch self {
        case .underTwoHours: return "Less than 2 hours"
        case .twoToFourHours: return "2 — 4 hours"
        case .fourToSixHours: return "4 — 6 hours"
        case .sixHoursPlus: return "6+ hours"
        }
    }
}

extension OnboardingAnswers.Procrastination {
    var optionTitle: String {
        switch self {
        case .everyDay: return "Every day"
        case .everyWeek: return "Every single week"
        case .everyMonth: return "Every month"
        case .stoppedLyingToMyself: return "I stopped lying to myself"
        }
    }

    /// Frame order (worst first) — NOT `allCases`, whose order serves the scale.
    /// Never reorder the enum to fix this: OnboardingAnswers reads it for points.
    static var displayOrder: [Self] { [.everyDay, .everyWeek, .everyMonth, .stoppedLyingToMyself] }
}

extension OnboardingAnswers.Struggle {
    var optionTitle: String {
        switch self {
        case .startStrongThenQuit: return "I start strong, then quit"
        case .threeDaysMax: return "I'm consistent 3 days max"
        case .cantEvenStart: return "I can't even get started"
        }
    }
}

extension OnboardingAnswers.Commitment {
    var optionTitle: String {
        switch self {
        case .extremely: return "Extremely — start today"
        case .very: return "Very — I want this"
        case .somewhat: return "A little — testing the waters"
        }
    }
}

/// Answers being collected. Optional until answered — the CTA of each screen is
/// disabled while its own field is nil (never a dead Continue).
struct OnboardingDraft: Equatable {
    var pain: Pain?
    var scrollTime: OnboardingAnswers.ScrollTime?
    var age: AgeBracket?
    var procrastination: OnboardingAnswers.Procrastination?
    var wakeTime: WakeBracket?
    var trainingLoad: TrainingLoad?
    var focusSpan: FocusSpan?
    var quitHistory: QuitHistory?
    var goals: Set<Goal> = []
    var struggle: OnboardingAnswers.Struggle?
    var commitment: OnboardingAnswers.Commitment?

    /// The typed answers OVREngine eats. `commitment` defaults to `.somewhat` (0 pt)
    /// until OB 16 answers it — decision D1 (2026-07-15): the diagnostic (OB 10) and
    /// the projection (OB 13) show the FLOOR, and the commitment bonus can only
    /// raise it. The user never watches his number go down.
    /// The scale itself lives in OnboardingAnswers' enums — never re-typed here.
    var answers: OnboardingAnswers {
        OnboardingAnswers(scrollTime: scrollTime ?? .sixHoursPlus,
                          procrastination: procrastination ?? .everyWeek,
                          struggle: struggle ?? .cantEvenStart,
                          commitment: commitment ?? .somewhat)
    }

    /// What the commitment answer is worth, revealed at OB 16/17 (D1).
    var commitmentBonus: Int { commitment?.points ?? 0 }
}
