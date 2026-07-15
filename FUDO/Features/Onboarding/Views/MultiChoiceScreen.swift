import SwiftUI

/// OB 07 — the only screen where he can say several things at once. Nothing is
/// mutually exclusive here: he's writing the promise the reflection reads back.
struct MultiChoiceScreen: View {
    let step: OnboardingStep
    let eyebrow: String
    let title: String
    var subtitle: String?
    let options: [Goal]
    @Binding var selection: Set<Goal>
    let onAdvance: () -> Void
    let onBack: () -> Void

    private static var rowStagger: TimeInterval { 0.04 }

    @State private var revealed = false

    var body: some View {
        OnboardingScaffold(step: step, eyebrow: eyebrow, title: title, subtitle: subtitle,
                           canAdvance: !selection.isEmpty,
                           onBack: onBack, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    OptionRow(title: option.optionTitle,
                              isSelected: selection.contains(option)) {
                        toggle(option)
                    }
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 8)
                    .animation(AppAnimation.standard.delay(Double(index) * Self.rowStagger),
                               value: revealed)
                }
            }
        }
        .onAppear { revealed = true }
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
            MultiChoiceScreen(step: .goals, eyebrow: "YOUR TARGETS",
                              title: "What do you actually\nwant?",
                              subtitle: "Pick all that apply",
                              options: Goal.allCases,
                              selection: $selection,
                              onAdvance: {}, onBack: {})
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
