import Foundation

/// Every string the funnel RE-CUTS from the answers. Kept out of the views so the
/// copy is testable and lives in one place — a recut that drifts between two
/// screens is how a funnel stops sounding like it listened.
enum OnboardingCopy {

    // MARK: - OB 06 — the math

    static func shockLead(shock: ShockMath.Result) -> String {
        "At this pace, by age \(shock.horizonAge)\nyou will have scrolled away"
    }

    /// The line that proves the app heard OB 02. Same number, his own wound.
    static func shockRecut(pain: Pain, shock: ShockMath.Result) -> String {
        let amount = shock.headline
        switch pain {
        case .doomscrolling: return "That's \(amount) you will never scroll back."
        case .wakingUpEarly: return "That's \(amount) of mornings you slept through."
        case .trainingConsistently: return "That's \(amount) not spent training."
        case .reading: return "That's \(amount) of books you'll never read."
        case .stayingFocused: return "That's \(amount) your focus belonged to someone else."
        }
    }

    /// The Mao comfort pivot + the 30-day beat (brief, 2026-07-13). Commitment
    /// framing — a stake, never "studies say".
    static let shockPivot = "Monk mode exists exactly for this."
    static let shockStake = """
        Good habit or bad one, it holds the same way: about 30 days without breaking it. \
        That's the minimum stake to prove you own it.
        """

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

    static func enemyLine(_ struggle: OnboardingAnswers.Struggle) -> String {
        switch struggle {
        case .startStrongThenQuit: return "Your enemy: week two."
        case .threeDaysMax: return "Your enemy: 3-day consistency."
        case .cantEvenStart: return "Your enemy: the first step."
        }
    }

    static let reflectionClose = "Your protocol will be built on exactly that."

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
