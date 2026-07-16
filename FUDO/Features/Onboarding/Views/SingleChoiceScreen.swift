import SwiftUI

/// Every one-answer question of the funnel: OB 02, 03, 04, 05, 08 and 16.
/// One view, six screens — the questions differ, the screen doesn't.
///
/// `options` is passed explicitly rather than read from `allCases`: the frames
/// order some answers worst-first, while the enums are ordered by their OVR
/// scale. The display order bends; the enum never does (OnboardingAnswers reads
/// it for points).
struct SingleChoiceScreen<Option: Hashable>: View {
    let step: OnboardingStep
    let eyebrow: String
    let title: String
    var subtitle: String?
    let options: [Option]
    let titleFor: (Option) -> String
    @Binding var selection: Option?
    /// The line under the options — OB 16's "A little"? Then start small. 30 days."
    var hint: String?
    var ctaTitle: String = "Continue"
    let onAdvance: () -> Void

    // ONE choreography per screen (UX pass 2026-07-16): the slide-in IS the
    // entrance. No per-row stagger stacked on top of it.
    var body: some View {
        OnboardingScaffold(step: step, eyebrow: eyebrow, title: title, subtitle: subtitle,
                           ctaTitle: ctaTitle, canAdvance: selection != nil,
                           onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(options, id: \.self) { option in
                    OptionRow(title: titleFor(option),
                              isSelected: selection == option) {
                        selection = option
                    }
                }

                if let hint {
                    Text(hint)
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 8)
                }
            }
        }
    }
}

#if DEBUG
/// The five questions this one view serves. Unanswered vs answered is the state
/// worth judging: the CTA must read dead, not absent.
private struct SingleChoicePreviewHost<Option: Hashable>: View {
    let step: OnboardingStep
    let eyebrow: String
    let title: String
    let options: [Option]
    let titleFor: (Option) -> String
    @State var selection: Option?
    var hint: String?

    var body: some View {
        OnboardingPreviewChrome {
            SingleChoiceScreen(step: step, eyebrow: eyebrow, title: title,
                               options: options, titleFor: titleFor,
                               selection: $selection, hint: hint,
                               onAdvance: {})
        }
    }
}

#Preview("OB 02 — pain point (untouched)") {
    SingleChoicePreviewHost(step: .painPoint, eyebrow: "START HERE",
                            title: "What's the ONE thing\nyou can't control alone?",
                            options: Pain.allCases, titleFor: \.optionTitle,
                            selection: nil)
}

#Preview("OB 02 — pain point (answered)") {
    SingleChoicePreviewHost(step: .painPoint, eyebrow: "START HERE",
                            title: "What's the ONE thing\nyou can't control alone?",
                            options: Pain.allCases, titleFor: \.optionTitle,
                            selection: .doomscrolling)
}

#Preview("OB 03 — scroll hours") {
    SingleChoicePreviewHost(step: .scrollHours, eyebrow: "BE HONEST",
                            title: "How many hours a day\ndo you scroll?",
                            options: OnboardingAnswers.ScrollTime.allCases,
                            titleFor: \.optionTitle,
                            selection: .fourToSixHours)
}

#Preview("OB 04 — age") {
    SingleChoicePreviewHost(step: .age, eyebrow: "QUICK ONE",
                            title: "How old are you?",
                            options: AgeBracket.allCases, titleFor: \.optionTitle,
                            selection: .young1824)
}

#Preview("OB 05 — procrastination") {
    SingleChoicePreviewHost(step: .procrastination, eyebrow: "NO JUDGMENT",
                            title: "How often do you say\n\"I'll start Monday\"?",
                            options: OnboardingAnswers.Procrastination.displayOrder,
                            titleFor: \.optionTitle,
                            selection: .everyWeek)
}

#Preview("OB 08 — struggle") {
    SingleChoicePreviewHost(step: .struggle, eyebrow: "THE REAL TALK",
                            title: "What's your real problem?",
                            options: OnboardingAnswers.Struggle.allCases,
                            titleFor: \.optionTitle,
                            selection: .threeDaysMax)
}
#endif
