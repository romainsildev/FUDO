import SwiftUI

/// OB 07 — the only screen where he can say several things at once. Nothing is
/// mutually exclusive here: he's writing the promise the reflection reads back.
struct MultiChoiceScreen: View {
    let step: OnboardingStep
    let title: String
    var subtitle: String?
    let options: [Goal]
    @Binding var selection: Set<Goal>
    let onAdvance: () -> Void

    // ONE choreography per screen (UX pass 2026-07-16): the slide-in IS the
    // entrance. No per-row stagger stacked on top of it.
    var body: some View {
        OnboardingScaffold(step: step, title: title, subtitle: subtitle,
                           canAdvance: !selection.isEmpty,
                           onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(options, id: \.self) { option in
                    OptionRow(title: option.optionTitle,
                              isSelected: selection.contains(option)) {
                        toggle(option)
                    }
                }
            }
        }
    }

    private func toggle(_ option: Goal) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}

#if DEBUG
private struct MultiChoicePreviewHost: View {
    @State var selection: Set<Goal>

    var body: some View {
        OnboardingPreviewChrome {
            MultiChoiceScreen(step: .goals, 
                              title: "What do you actually\nwant?",
                              subtitle: "Pick all that apply",
                              options: Goal.allCases,
                              selection: $selection,
                              onAdvance: {})
        }
    }
}

/// Empty is the state to judge: the CTA must be visibly dead until he picks one.
#Preview("OB 07 — goals (none picked)") {
    MultiChoicePreviewHost(selection: [])
}

#Preview("OB 07 — goals (three picked)") {
    MultiChoicePreviewHost(selection: [.leanerBody, .killScrolling, .harderMindset])
}
#endif
