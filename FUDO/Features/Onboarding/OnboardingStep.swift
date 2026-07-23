import Foundation

/// The onboarding screens, in order. The progress bar's total is DERIVED from
/// this enum (never hand-numbered): add a step and every fraction re-computes.
///
/// RESTRUCTURED 2026-07-16 (RiteOff pattern): the narrative loader ANALYZES the
/// quiz and lands BEFORE the OVR reveal — quiz → loader → diagnostic reveal →
/// compose → projection (which needs the chosen duration, so it stays after
/// compose, with a short "Locking…" beat instead of a second loader).
///
/// COMPOSE SPLIT (tester batch #1, 2026-07-16, Romain): OB 11 becomes two
/// screens — duration alone (11a), then the rules (11b). One decision per
/// screen; the projection still follows the rules, so the date has its duration.
///
/// BATCH #2 (2026-07-16, Romain): four habit questions join the quiz — they
/// feed the report's benchmarked sections (morning / training / focus / track
/// record). The shock beat keeps its inputs (scroll + age) right before it;
/// the habit block lands after the blow. A one-sentence EXPLAINER sits between
/// the reveal and 11a: "we've picked your actions" gets its own beat.
enum OnboardingStep: Int, CaseIterable {
    // Act 0 — welcome (no progress bar) + the launch beat (batch #3): "ONLY 60
    // SECONDS", no CTA, auto-advance — it throws him into the quiz.
    case splash, transformation, pain, mechanism, sixtySeconds
    // Act 1 — the quiz
    case painPoint, scrollHours, age, procrastination, shockStat,
         wakeUp, training, focus, goals, struggle, attempts, reflection
    // Act 1bis — analysis, report & reveal
    case loaderAnalysis, report, diagnostic
    // Act 2 — climax
    case protocolIntro, composeDuration, composeRules, projection, firstCheck, socialProof
    // Act 3 — engagement & contract
    case commitment, contract, paywall
    // Act 4 — post-paywall
    case notifications, loaderSetup, welcomeDojo, widgetPromo

    /// Hidden on the welcome act, both loaders, the paywall and the whole
    /// post-paywall trio (brief + decision D6: a bar pinned at 100 % is noise).
    /// The bar covers the quiz AND the reveal that follows the analysis loader.
    var showsProgress: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism, .sixtySeconds,
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
        case .painPoint, .scrollHours, .age, .procrastination,
             .wakeUp, .training, .focus, .struggle, .attempts,
             .composeDuration, .composeRules:
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

    /// Stable snake_case name for `onboarding_screen_viewed` (ANALYTICS-PLAN §1.2).
    /// `step` = `rawValue` (the OB index); this is the paired `screen` value. New
    /// steps keep the same naming pattern — never a numbered event per screen.
    var analyticsScreen: String {
        switch self {
        case .splash: return "splash"
        case .transformation: return "welcome_transformation"
        case .pain: return "welcome_pain"
        case .mechanism: return "welcome_mechanism"
        case .sixtySeconds: return "sixty_seconds"
        case .painPoint: return "pain_point"
        case .scrollHours: return "scroll_hours"
        case .age: return "age"
        case .procrastination: return "procrastination"
        case .shockStat: return "shock_stat"
        case .wakeUp: return "wake_up"
        case .training: return "training"
        case .focus: return "focus"
        case .goals: return "goals"
        case .struggle: return "struggle"
        case .attempts: return "attempts"
        case .reflection: return "reflection"
        case .loaderAnalysis: return "loader_analysis"
        case .report: return "report"
        case .diagnostic: return "diagnostic"
        case .protocolIntro: return "protocol_intro"
        case .composeDuration: return "compose_duration"
        case .composeRules: return "compose_rules"
        case .projection: return "projection"
        case .firstCheck: return "first_check"
        case .socialProof: return "social_proof"
        case .commitment: return "commitment"
        case .contract: return "contract"
        case .paywall: return "paywall"
        case .notifications: return "notifications"
        case .loaderSetup: return "loader_setup"
        case .welcomeDojo: return "welcome_dojo"
        case .widgetPromo: return "widget_promo"
        }
    }
}
