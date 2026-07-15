import Foundation

/// The 25 onboarding screens, in order. The progress bar's total is DERIVED from
/// this enum (never hand-numbered): add a step and every fraction re-computes.
enum OnboardingStep: Int, CaseIterable {
    // Act 0 — welcome (no progress bar)
    case splash, transformation, pain, mechanism
    // Act 1 — diagnostic & self-persuasion
    case painPoint, scrollHours, age, procrastination, shockStat, goals, struggle, reflection, diagnostic
    // Act 2 — climax
    case compose, loaderBuilding, projection, firstCheck, socialProof
    // Act 3 — engagement & contract
    case commitment, contract, paywall
    // Act 4 — post-paywall
    case notifications, loaderSetup, welcomeDojo, widgetPromo

    /// Hidden on the welcome act, both loaders, the paywall and the whole
    /// post-paywall trio (brief + decision D6: a bar pinned at 100 % is noise).
    var showsProgress: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism,
             .loaderBuilding, .loaderSetup, .paywall,
             .notifications, .welcomeDojo, .widgetPromo:
            return false
        default:
            return true
        }
    }

    /// Back is offered on the questions only. The walls (reflection, first check,
    /// social proof, commitment, contract), the loaders and the post-paywall trio
    /// have no way back — matching the frames.
    var showsBack: Bool {
        switch self {
        case .painPoint, .scrollHours, .age, .procrastination, .shockStat,
             .goals, .struggle, .diagnostic, .compose, .projection:
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
