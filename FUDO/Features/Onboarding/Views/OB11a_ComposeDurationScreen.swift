import SwiftUI

/// OB 11a — the duration, full screen (batch #2 refonte): four stacked
/// full-width cards, paywall pattern. The 60 leads — pre-selected (it IS the
/// recommendation the view model defaults to), green badge, slightly larger.
/// The "we picked your actions" sentence moved to its own explainer screen;
/// this screen asks ONE question, big.
struct ComposeDurationScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    private var setup: ChallengeSetupViewModel { viewModel.setup }

    var body: some View {
        OnboardingScaffold(step: .composeDuration, title: "How long?",
                           canAdvance: true, onAdvance: viewModel.advance) {
            cards
        }
        .task { viewModel.prepareCompose() }
    }

    private var cards: some View {
        let recommendedDays = PresetCatalog.definition(for: setup.recommendedPreset).durationDays
        return VStack(spacing: 12) {
            ForEach(PresetCatalog.all) { definition in
                DurationCard(definition: definition,
                             isSelected: setup.durationDays == definition.durationDays,
                             badge: badge(for: definition, recommendedDays: recommendedDays),
                             isProminent: definition.durationDays == recommendedDays) {
                    setup.selectDuration(days: definition.durationDays)
                }
            }
        }
        // The recommended card scales up 1.03 — give the stack the breath it needs.
        .padding(.vertical, 4)
    }

    /// The ego ladder (batch #3): green stays UNIQUE to the 60's recommendation;
    /// the 120 baits in vermillon — a dare, not a validation.
    private func badge(for definition: PresetDefinition, recommendedDays: Int) -> DurationBadge? {
        if definition.durationDays == recommendedDays {
            return DurationBadge(text: "RECOMMENDED\nFOR YOU", color: FudoColor.positive)
        }
        if definition.preset == .monk120 {
            return DurationBadge(text: "RECOMMENDED IF\nYOU'RE A KILLER", color: FudoColor.accent)
        }
        return nil
    }
}

#if DEBUG
#Preview("OB 11a — duration cards (60 pre-selected)") {
    OnboardingPreviewChrome {
        ComposeDurationScreen(viewModel: OnboardingPreviewFactory.viewModel(step: .composeDuration))
    }
}

/// A card he picked himself: the 60 keeps its badge and size but loses the
/// selection hairline to the 120.
#Preview("OB 11a — duration cards (120 picked)") {
    let viewModel = OnboardingPreviewFactory.viewModel(step: .composeDuration)
    viewModel.setup.selectDuration(days: 120)
    return OnboardingPreviewChrome {
        ComposeDurationScreen(viewModel: viewModel)
    }
}
#endif
