import SwiftUI

/// OB 16 — the last question is a vow in disguise, cut cinematic (design pass
/// 2026-07-22, Headway/Flo grammar): full-bleed dark, ONE title line, zero
/// standing sub-text, three TALL rows with big type entering on a stagger.
/// Selection = a brief vermilion edge flash + medium haptic, and the "+N OVR"
/// bonus counts up INSIDE the row — no floating overlay. The signature (OB 17)
/// stays the climax; this screen never doubles its gesture.
///
/// There is no wrong answer: "A little" is welcomed, not punished — its hint
/// and the "Change it now" micro-CTA (batch #10, untouched) only appear once
/// he picks it. And his answer PAYS — the only question of the funnel that
/// puts points on the table (D1).
struct CommitmentScreen: View {
    @Binding var selection: OnboardingAnswers.Commitment?
    /// The duration he chose at 11a — the "Change it now" nudge only appears if
    /// he's on something longer than 30 and answers "A little".
    var currentDurationDays: Int = 30
    var onPickThirtyDays: () -> Void = {}
    let onAdvance: () -> Void

    @State private var revealed = false
    /// Which row is mid-flash — the brief vermilion edge on selection.
    @State private var flashing: OnboardingAnswers.Commitment?
    @State private var switchedToThirty = false

    private static let rowStagger: TimeInterval = 0.08
    private static let flashDuration: TimeInterval = 0.18
    private static let rowHeight: CGFloat = 76
    /// Frame order — same as allCases, but stated so a reorder of the scale can't
    /// silently reshuffle the screen.
    private static let order: [OnboardingAnswers.Commitment] = [.extremely, .very, .somewhat]

    var body: some View {
        OnboardingScaffold(step: .commitment,
                           title: "How committed are you?",
                           canAdvance: selection != nil, onAdvance: onAdvance) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(Self.order.enumerated()), id: \.element) { index, option in
                    row(option, index: index)
                }

                // "A little" context — conditional, never a standing sub-text.
                if selection == .somewhat {
                    Text("\"A little\"? Then start small. 30 days.")
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                changeDurationNudge
            }
            .animation(AppAnimation.standard, value: selection)
            .animation(AppAnimation.standard, value: switchedToThirty)
        }
        .onAppear { revealed = true }
    }

    /// Under the "A little" hint: a discrete bright-red micro-CTA that drops the
    /// draft's duration to 30 without leaving the screen. Shown only when he
    /// picked longer than 30 AND answered "A little"; once tapped it becomes a
    /// brief confirmation. (Batch #10, kept as-is.)
    @ViewBuilder private var changeDurationNudge: some View {
        if selection == .somewhat {
            if switchedToThirty {
                Label("Now 30 days.", systemImage: "checkmark")
                    .fudoFont(.caption(12, weight: .semibold))
                    .foregroundStyle(FudoColor.positive)
                    .padding(.top, 6)
                    .transition(.opacity)
            } else if currentDurationDays != 30 {
                Button {
                    Haptics.light()
                    onPickThirtyDays()
                    withAnimation(AppAnimation.standard) { switchedToThirty = true }
                } label: {
                    Text("Change it now")
                        .fudoFont(.caption(13, weight: .bold))
                        .foregroundStyle(FudoColor.accentPressed)
                        .padding(.top, 6)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Rows (tall, big type, integrated bonus)

    private func row(_ option: OnboardingAnswers.Commitment, index: Int) -> some View {
        CommitmentRow(title: option.optionTitle,
                      points: option.points,
                      isSelected: selection == option,
                      isFlashing: flashing == option,
                      height: Self.rowHeight) {
            select(option)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 14)
        .animation(AppAnimation.standard.delay(Double(index) * Self.rowStagger), value: revealed)
    }

    /// Selection lands with weight: medium haptic (the vow, not a checkbox tap)
    /// and one brief vermilion edge flash that settles back to the selected state.
    private func select(_ option: OnboardingAnswers.Commitment) {
        selection = option
        Haptics.medium()
        flashing = option
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.flashDuration))
            guard flashing == option else { return }
            withAnimation(.easeOut(duration: Self.flashDuration)) { flashing = nil }
        }
    }
}

/// One tall commitment row. Bigger type than an OptionRow, and the "+N OVR"
/// bonus lives INSIDE it: on selection the number counts up in the trailing
/// slot and stays — the payoff belongs to the row he chose, not to an overlay
/// drifting over the screen. `.somewhat` (0 pts) shows nothing: no "+0",
/// no penalty, no shame.
private struct CommitmentRow: View {
    let title: String
    let points: Int
    let isSelected: Bool
    let isFlashing: Bool
    let height: CGFloat
    let action: () -> Void

    @State private var counted: Double = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .fudoFont(.title(20, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if isSelected && points > 0 {
                    bonus
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                shape.fill(isSelected
                           ? FudoColor.accentDeep.opacity(0.35)
                           : FudoColor.bgCard)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        // Selection breathes at the house pace; deselection snaps (the OB 02
        // lesson: two lit rows read as multi-select).
        .animation(isSelected ? AppAnimation.standard
                              : .easeOut(duration: OnboardingMetrics.optionDeselect),
                   value: isSelected)
        .onChange(of: isSelected, initial: true) { _, selected in
            guard points > 0 else { return }
            if selected {
                counted = 0
                withAnimation(.easeOut(duration: 0.5)) { counted = Double(points) }
            } else {
                counted = 0
            }
        }
    }

    /// The flash is the brightest instant, then it settles on the selected edge.
    private var borderColor: Color {
        if isFlashing { return FudoColor.accentPressed }
        return isSelected ? FudoColor.accent : FudoColor.border
    }

    private var bonus: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowtriangle.up.fill")
                .fudoFont(.glyph(10))
                .foregroundStyle(FudoColor.positive)
            CountUpText(value: counted) { "+\(Int(max(0, $0).rounded())) OVR" }
                .fudoFont(.stat(16))
                .foregroundStyle(FudoColor.textPrimary)
        }
        .allowsHitTesting(false)
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

/// +2 — the biggest bonus the funnel hands out, counted up inside the row.
#Preview("OB 16 — Extremely") {
    CommitmentPreviewHost(selection: .extremely)
}

#Preview("OB 16 — Very") {
    CommitmentPreviewHost(selection: .very)
}

/// Worth 0: no badge, no penalty. The conditional hint is the whole answer.
#Preview("OB 16 — A little") {
    CommitmentPreviewHost(selection: .somewhat)
}
#endif
