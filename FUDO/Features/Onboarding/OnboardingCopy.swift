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

    // MARK: - OB 12 — the orbiting stats

    /// One stat orbiting the build loader — his own numbers thrown back at him
    /// while the protocol "computes".
    struct LoaderStat: Equatable {
        var number: String?
        var label: String
        var emphasis: Bool = false
    }

    /// Personalized from the draft — every value is an answer he gave, never an
    /// invented measurement (D4).
    static func buildLoaderStats(draft: OnboardingDraft, ovr: Int, days: Int) -> [LoaderStat] {
        var stats: [LoaderStat] = []
        if let scroll = draft.scrollTime {
            stats.append(LoaderStat(number: scroll.optionTitle, label: "scrolled daily"))
        }
        stats.append(LoaderStat(number: "OVR \(ovr)", label: "your start", emphasis: true))
        stats.append(LoaderStat(number: "\(days)", label: "days planned"))
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
    /// OB 15 — no rating line and no stars: both ARE a rating claim.
    static let proofTitle = "Men like you,\nlocked in."

    // PLACEHOLDER — real, consented tester quotes required before submit.
    // See docs/ONBOARDING-PLAN.md §"Le point resté ouvert". Shipping invented
    // quotes attributed to named people is not a copy choice, it's a claim.
    static let testimonials: [(quote: String, author: String)] = [
        ("Held 60 days for the first time in my life.", "— Ryan, 19 — OVR 71"),
        ("Started at 41. OVR 91 today. Different person.", "— Marcus, 22 — Sensei"),
        ("The character evolving is what kept me going.", "— Tom, 24 — OVR 84"),
    ]

    /// OB 18 — was "you are statistically dead by day 4" (no such statistic exists).
    static let reminderStake = "Without it, most men are done by day 4."

    /// OB 21 — was "Users with the widget are 2× more likely to finish" (unmeasured).
    static let widgetStake = "The widget is the difference between remembering and finishing."
}
