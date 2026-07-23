import Testing
@testable import FUDO

/// Batch #12 locks: 11b's personalized rules and OB 07's dynamic goal order.
/// Pure logic — no SwiftData, no container (engine-suite rule, carnet).
struct OnboardingPersonalizationTests {

    private var heavyScroller: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .doomscrolling
        draft.scrollTime = .sixHoursPlus
        draft.focusSpan = .underTen
        draft.wakeTime = .sixToSeven
        draft.trainingLoad = .threeToFour
        return draft
    }

    // MARK: - 11b rules

    @Test func personalizedRulesPreselectFourAndKeepTheWholeCatalogVisible() {
        let rules = RulePersonalizer.rules(for: heavyScroller)
        #expect(rules.filter(\.isEnabled).count == RulePersonalizer.preselectionCount)
        // The whole catalog stays visible — same row count as the full protocol.
        #expect(rules.count == PresetCatalog.definition(for: .monk120).defaultRules.count)
    }

    @Test func theHeavyScrollerOpensOnTheSocialCap() {
        let rules = RulePersonalizer.rules(for: heavyScroller)
        // Strongest signal first: pain + 6h+ scroll + dead focus all point at
        // the feed — the social cap must lead his protocol.
        #expect(rules.first?.iconName == "iphone.slash")
        #expect(rules.first?.isEnabled == true)
    }

    @Test func personalizationIsDeterministic() {
        #expect(RulePersonalizer.rules(for: heavyScroller).map(\.title)
                == RulePersonalizer.rules(for: heavyScroller).map(\.title))
    }

    @Test func anEmptyDraftStillPreselectsFour() {
        // No answers (DEBUG jump paths): the personalizer must not ship an
        // empty protocol — catalog order fills the four slots.
        let rules = RulePersonalizer.rules(for: OnboardingDraft())
        #expect(rules.filter(\.isEnabled).count == RulePersonalizer.preselectionCount)
    }

    // MARK: - OB 07 goal order

    @Test func theHeavyScrollerSeesKillScrollingFirst() {
        #expect(Goal.displayOrder(for: heavyScroller).first == .killScrolling)
    }

    @Test func anEmptyDraftKeepsTheEnumOrder() {
        #expect(Goal.displayOrder(for: OnboardingDraft()) == Goal.allCases)
    }

    @Test func displayOrderIsAPermutationOfAllCases() {
        let order = Goal.displayOrder(for: heavyScroller)
        #expect(Set(order) == Set(Goal.allCases))
        #expect(order.count == Goal.allCases.count)
    }
}
