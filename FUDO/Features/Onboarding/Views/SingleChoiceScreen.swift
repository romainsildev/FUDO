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
    let onBack: () -> Void

    private static var rowStagger: TimeInterval { 0.04 }

    @State private var revealed = false

    var body: some View {
        OnboardingScaffold(step: step, eyebrow: eyebrow, title: title, subtitle: subtitle,
                           ctaTitle: ctaTitle, canAdvance: selection != nil,
                           onBack: onBack, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    OptionRow(title: titleFor(option),
                              isSelected: selection == option) {
                        selection = option
                    }
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 8)
                    .animation(AppAnimation.standard.delay(Double(index) * Self.rowStagger),
                               value: revealed)
                }

                if let hint {
                    Text(hint)
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 8)
                        .opacity(revealed ? 1 : 0)
                }
            }
        }
        .onAppear { revealed = true }
    }
}
