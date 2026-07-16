import Foundation

/// The onboarding screens, in order. The progress bar's total is DERIVED from
/// this enum (never hand-numbered): add a step and every fraction re-computes.
///
/// RESTRUCTURED 2026-07-16 (RiteOff pattern): the narrative loader ANALYZES the
/// quiz and lands BEFORE the OVR reveal — quiz → loader → diagnostic reveal →
/// compose → projection (which needs the chosen duration, so it stays after
/// compose, with a short "Locking…" beat instead of a second loader).
enum OnboardingStep: Int, CaseIterable {
    // Act 0 — welcome (no progress bar)
    case splash, transformation, pain, mechanism
    // Act 1 — the quiz
    case painPoint, scrollHours, age, procrastination, shockStat, goals, struggle, reflection
    // Act 1bis — analysis & reveal
    case loaderAnalysis, diagnostic
    // Act 2 — climax
    case compose, projection, firstCheck, socialProof
    // Act 3 — engagement & contract
    case commitment, contract, paywall
    // Act 4 — post-paywall
    case notifications, loaderSetup, welcomeDojo, widgetPromo

    /// Hidden on the welcome act, both loaders, the paywall and the whole
    /// post-paywall trio (brief + decision D6: a bar pinned at 100 % is noise).
    /// The bar covers the quiz AND the reveal that follows the analysis loader.
    var showsProgress: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism,
             .loaderAnalysis, .loaderSetup, .paywall,
             .notifications, .welcomeDojo, .widgetPromo:
            return false
        default:
            return true
        }
    }

    /// Back is offered on the QUESTIONS only. The walls (reflection, first
    /// check, social proof, commitment, contract), the loaders, the post-paywall
    /// trio AND the reveals (shock stat, diagnostic, projection — one-way by
    /// design, 2026-07-16: going back weakens the funnel) have no way back.
    var showsBack: Bool {
        switch self {
        case .painPoint, .scrollHours, .age, .procrastination, .struggle, .compose:
            return true
        default:
            return false
        }
    }

    /// The video act — crossfade only, never a slide.
    var isWelcome: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism:
            return true
        default:
            return false
        }
    }

    /// The screens that carry the bar, in order — the ONE list the bar counts.
    static var progressSteps: [OnboardingStep] { allCases.filter(\.showsProgress) }

    static var progressTotal: Int { progressSteps.count }

    /// 1-based position among the progress-carrying steps; nil when the bar is hidden.
    var progressIndex: Int? {
        Self.progressSteps.firstIndex(of: self).map { $0 + 1 }
    }

    /// 0…1 fill of the bar. Full on the contract — the last bar-carrying screen.
    var progressFraction: Double? {
        progressIndex.map { Double($0) / Double(Self.progressTotal) }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
