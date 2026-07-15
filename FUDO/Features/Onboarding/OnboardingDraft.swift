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
enum AgeBracket: CaseIterable, Equatable {
    case teen1317, young1824, adult2534, mature35plus

    var optionTitle: String {
        switch self {
        case .teen1317: return "13 — 17"
        case .young1824: return "18 — 24"
        case .adult2534: return "25 — 34"
        case .mature35plus: return "35+"
        }
    }
}

/// What he actually wants (OB 07, multi-select). Feeds the reflection only.
enum Goal: CaseIterable, Equatable {
    case leanerBody, earlyWakeUps, killScrolling, readDaily, harderMindset, coldShowers

    var optionTitle: String {
        switch self {
        case .leanerBody: return "Leaner, stronger body"
        case .earlyWakeUps: return "Master early wake-ups"
        case .killScrolling: return "Kill zombie scrolling"
        case .readDaily: return "Read every day"
        case .harderMindset: return "Harder mindset"
        case .coldShowers: return "Cold showers"
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
        case .everyWeek: return "Every single week"
        case .everyMonth: return "Every month"
        case .stoppedLyingToMyself: return "I stopped lying to myself"
        }
    }

    /// Frame order (worst first) — NOT `allCases`, whose order serves the scale.
    /// Never reorder the enum to fix this: OnboardingAnswers reads it for points.
    static var displayOrder: [Self] { [.everyWeek, .everyMonth, .stoppedLyingToMyself] }
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
