import Foundation

/// 11b's personalization (batch #12): the FULL rule catalog, with ~4 rules
/// PRE-SELECTED from his quiz answers — the heavy scroller opens on a social
/// cap, the late riser on a wake-up rule. Deterministic: same draft, same
/// protocol, no randomness.
///
/// The catalog itself stays `PresetCatalog`'s (the hardcore protocol IS the
/// full rule set) — this file only decides which rows start enabled. Onboarding
/// only: the standalone/full-flow skins keep their preset defaults.
enum RulePersonalizer {

    /// How many rules start enabled — the sweet spot's floor side.
    static let preselectionCount = 4

    /// The whole catalog, ordered: the ~4 his answers point at (enabled,
    /// strongest signal first), then everything else (disabled, catalog order).
    static func rules(for draft: OnboardingDraft) -> [EditableRule] {
        let catalog = PresetCatalog.definition(for: .monk120).defaultRules
        // Stable ranking: sort by score descending, catalog order breaking ties.
        let ranked = catalog.enumerated().sorted { lhs, rhs in
            let l = score(lhs.element, draft: draft)
            let r = score(rhs.element, draft: draft)
            return l == r ? lhs.offset < rhs.offset : l > r
        }.map(\.element)

        let selected = ranked.prefix(preselectionCount).map { rule in
            var rule = rule
            rule.isEnabled = true
            return rule
        }
        let rest = ranked.dropFirst(preselectionCount).map { rule in
            var rule = rule
            rule.isEnabled = false
            return rule
        }
        return selected + rest
    }

    /// Affinity of one catalog rule to his answers. Matched on the rule's icon —
    /// the stable identity (titles carry baked values like the wake-up hour).
    private static func score(_ rule: EditableRule, draft: OnboardingDraft) -> Int {
        switch rule.iconName {
        case "figure.strengthtraining.traditional":   // Daily workout
            var score = 0
            if draft.pain == .trainingConsistently { score += 2 }
            if draft.goals.contains(.leanerBody) { score += 2 }
            switch draft.trainingLoad {
            case .zero: score += 2
            case .oneToTwo: score += 1
            default: break
            }
            return score

        case "iphone.slash":                          // Social media under 1h
            var score = 0
            if draft.pain == .doomscrolling { score += 2 }
            if draft.goals.contains(.killScrolling) { score += 2 }
            switch draft.scrollTime {
            case .sixHoursPlus: score += 2
            case .fourToSixHours: score += 1
            default: break
            }
            if draft.focusSpan == .underTen { score += 1 }
            return score

        case "sunrise.fill":                          // Wake up before X
            var score = 0
            if draft.pain == .wakingUpEarly { score += 2 }
            if draft.goals.contains(.earlyWakeUps) { score += 2 }
            switch draft.wakeTime {
            case .afterNine: score += 2
            case .sevenToNine: score += 1
            default: break
            }
            return score

        case "book.fill":                             // Read 30 min
            var score = 0
            if draft.pain == .reading { score += 2 }
            if draft.goals.contains(.readDaily) { score += 2 }
            return score

        case "figure.mind.and.body":                  // Meditate 10 min
            var score = 0
            switch draft.focusSpan {
            case .underTen: score += 2
            case .tenToThirty: score += 1
            default: break
            }
            if draft.pain == .stayingFocused { score += 2 }
            if draft.goals.contains(.harderMindset) { score += 1 }
            return score

        case "drop.fill":                             // Cold shower
            var score = 0
            if draft.goals.contains(.coldShowers) { score += 2 }
            if draft.goals.contains(.harderMindset) { score += 1 }
            return score

        case "square.and.pencil":                     // One-line journal
            var score = 0
            if draft.struggle == .cantEvenStart { score += 1 }
            if draft.quitHistory == .lostCount { score += 1 }
            return score

        default:                                      // No alcohol & future rules
            return 0
        }
    }
}
