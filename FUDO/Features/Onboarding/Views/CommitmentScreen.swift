import SwiftUI

/// OB 16 — the last question is a vow in disguise. There is no wrong answer:
/// "A little" is welcomed, not punished ("Then start small. 30 days."), so he
/// answers true. And his answer PAYS — it's the only question of the funnel that
/// puts points on the table (D1).
///
/// Its own screen rather than a `SingleChoiceScreen` skin: the floating bonus is
/// the whole beat, and it belongs to this question alone.
struct CommitmentScreen: View {
    @Binding var selection: OnboardingAnswers.Commitment?
    let onAdvance: () -> Void

    @State private var revealed = false
    @State private var bonusShown: OnboardingAnswers.Commitment?

    private static let rowStagger: TimeInterval = 0.04
    private static let bonusLinger: TimeInterval = 1.2
    /// Frame order — same as allCases, but stated so a reorder of the scale can't
    /// silently reshuffle the screen.
    private static let order: [OnboardingAnswers.Commitment] = [.extremely, .very, .somewhat]

    var body: some View {
        OnboardingScaffold(step: .commitment, 
                           title: "How committed\nare you, really?",
                           canAdvance: selection != nil, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(Self.order.enumerated()), id: \.element) { index, option in
                    row(option, index: index)
                }

                Text("\"A little\"? Then start small. 30 days.")
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 8)
                    .opacity(revealed ? 1 : 0)
            }
        }
        .onAppear { revealed = true }
    }

    private func row(_ option: OnboardingAnswers.Commitment, index: Int) -> some View {
        OptionRow(title: option.optionTitle, isSelected: selection == option) {
            selection = option
            showBonus(for: option)
        }
        .overlay(alignment: .trailing) { bonusBadge(for: option) }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 8)
        .animation(AppAnimation.standard.delay(Double(index) * Self.rowStagger), value: revealed)
    }

    /// The floating "+2 OVR" — what makes it legible, two screens later, that the
    /// contract's number climbed since the diagnostic. `.somewhat` is worth 0, so
    /// it shows nothing: no "+0", no penalty, no shame.
    @ViewBuilder private func bonusBadge(for option: OnboardingAnswers.Commitment) -> some View {
        if bonusShown == option, option.points > 0 {
            HStack(spacing: 3) {
                Image(systemName: "arrowtriangle.up.fill")
                    .fudoFont(.glyph(9))
                    .foregroundStyle(FudoColor.positive)
                Text("+\(option.points) OVR")
                    .fudoFont(.stat(13))
                    .foregroundStyle(FudoColor.textPrimary)
            }
            .padding(.trailing, FudoSpacing.cardPadding)
            .transition(.opacity.combined(with: .offset(y: 14)))
            .allowsHitTesting(false)
        }
    }

    private func showBonus(for option: OnboardingAnswers.Commitment) {
        guard option.points > 0 else {
            withAnimation(AppAnimation.standard) { bonusShown = nil }
            return
        }
        withAnimation(AppAnimation.standard) { bonusShown = option }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.bonusLinger))
            guard bonusShown == option else { return }   // he changed his mind meanwhile
            withAnimation(AppAnimation.standard) { bonusShown = nil }
        }
    }
}

#if DEBUG
private struct CommitmentPreviewHost: View {
    @State var selection: OnboardingAnswers.Commitment?

    var body: some View {
        OnboardingPreviewChrome {
            CommitmentScreen(selection: $selection, onAdvance: {})
        }
    }
}

#Preview("OB 16 — untouched") {
    CommitmentPreviewHost(selection: nil)
}

/// +2 — the biggest bonus the funnel hands out.
#Preview("OB 16 — Extremely") {
    CommitmentPreviewHost(selection: .extremely)
}

#Preview("OB 16 — Very") {
    CommitmentPreviewHost(selection: .very)
}

/// Worth 0: no badge, no penalty. The hint under the rows is the whole answer.
#Preview("OB 16 — A little") {
    CommitmentPreviewHost(selection: .somewhat)
}
#endif
