import Foundation

/// Onboarding → analytics glue (ANALYTICS-PLAN §1.2 / §4). The ONE place quiz
/// answers become anonymous strings: brackets, never the exact age; enum slugs,
/// never free text. Kept out of Core so the answer enums stay analytics-free.

// MARK: - Anonymous values (one per answer enum)

extension Pain {
    var analyticsValue: String {
        switch self {
        case .doomscrolling: return "doomscrolling"
        case .wakingUpEarly: return "waking_up_early"
        case .trainingConsistently: return "training"
        case .reading: return "reading"
        case .stayingFocused: return "focus"
        }
    }
}

extension AgeBracket {
    /// Bracket only — the exact age never leaves the device (plan §1.2).
    var analyticsValue: String {
        switch self {
        case .teen1317: return "13-17"
        case .young1824: return "18-24"
        case .adult2534: return "25-34"
        case .mature35plus: return "35-54"
        case .senior55plus: return "55+"
        }
    }
}

extension WakeBracket {
    var analyticsValue: String {
        switch self {
        case .beforeSix: return "before_6"
        case .sixToSeven: return "6-7"
        case .sevenToNine: return "7-9"
        case .afterNine: return "after_9"
        }
    }
}

extension TrainingLoad {
    var analyticsValue: String {
        switch self {
        case .zero: return "0"
        case .oneToTwo: return "1-2"
        case .threeToFour: return "3-4"
        case .fivePlus: return "5+"
        }
    }
}

extension FocusSpan {
    var analyticsValue: String {
        switch self {
        case .underTen: return "under_10"
        case .tenToThirty: return "10-30"
        case .thirtyToSixty: return "30-60"
        case .hourPlus: return "60+"
        }
    }
}

extension QuitHistory {
    var analyticsValue: String {
        switch self {
        case .firstTime: return "first_time"
        case .twoToThree: return "2-3"
        case .lostCount: return "lost_count"
        }
    }
}

extension Goal {
    var analyticsValue: String {
        switch self {
        case .leanerBody: return "leaner_body"
        case .earlyWakeUps: return "early_wake_ups"
        case .killScrolling: return "kill_scrolling"
        case .readDaily: return "read_daily"
        case .harderMindset: return "harder_mindset"
        case .coldShowers: return "cold_showers"
        case .doWhatIveWanted: return "do_what_ive_wanted"
        case .moreEnergy: return "more_energy"
        }
    }
}

extension OnboardingAnswers.ScrollTime {
    var analyticsValue: String {
        switch self {
        case .underTwoHours: return "<2h"
        case .twoToFourHours: return "2-4h"
        case .fourToSixHours: return "4-6h"
        case .sixHoursPlus: return "6h+"
        }
    }
}

extension OnboardingAnswers.Procrastination {
    var analyticsValue: String {
        switch self {
        case .stoppedLyingToMyself: return "stopped_lying"
        case .everyMonth: return "monthly"
        case .everyWeek: return "weekly"
        case .everyDay: return "every_day"
        }
    }
}

extension OnboardingAnswers.Struggle {
    var analyticsValue: String {
        switch self {
        case .startStrongThenQuit: return "quit_fast"
        case .threeDaysMax: return "3_days_max"
        case .cantEvenStart: return "cant_start"
        }
    }
}

extension OnboardingAnswers.Commitment {
    var analyticsValue: String {
        switch self {
        case .extremely: return "extremely"
        case .very: return "very"
        case .somewhat: return "a_little"
        }
    }
}

// MARK: - Event payloads

enum OnboardingAnalytics {
    /// The `onboarding_question_answered` payload for a quiz step, or nil when the
    /// step isn't a question. Read at advance time (the answer is committed).
    static func questionAnswer(for step: OnboardingStep,
                               draft: OnboardingDraft) -> (question: String, answer: Any)? {
        switch step {
        case .painPoint:      return draft.pain.map { ("pain", $0.analyticsValue) }
        case .scrollHours:    return draft.scrollTime.map { ("scroll_hours", $0.analyticsValue) }
        case .age:            return draft.age.map { ("age", $0.analyticsValue) }
        case .procrastination:return draft.procrastination.map { ("procrastination", $0.analyticsValue) }
        case .wakeUp:         return draft.wakeTime.map { ("wake_up", $0.analyticsValue) }
        case .training:       return draft.trainingLoad.map { ("training", $0.analyticsValue) }
        case .focus:          return draft.focusSpan.map { ("focus", $0.analyticsValue) }
        case .goals:
            guard !draft.goals.isEmpty else { return nil }
            return ("goals", draft.goals.map(\.analyticsValue).sorted())
        case .struggle:       return draft.struggle.map { ("struggle", $0.analyticsValue) }
        case .attempts:       return draft.quitHistory.map { ("attempts", $0.analyticsValue) }
        case .commitment:     return draft.commitment.map { ("commitment", $0.analyticsValue) }
        default:              return nil
        }
    }

    /// Person properties ($set) at the end of onboarding — the ONLY four (plan §4).
    /// No PII, no free text: preset is its Codable data identity, never a title.
    static func personProperties(draft: OnboardingDraft, preset: ChallengePreset) -> [String: Any] {
        var props: [String: Any] = ["preset": preset.rawValue]
        if let scroll = draft.scrollTime { props["scroll_hours"] = scroll.analyticsValue }
        if let struggle = draft.struggle { props["struggle"] = struggle.analyticsValue }
        if let commitment = draft.commitment { props["commitment"] = commitment.analyticsValue }
        return props
    }
}
