import SwiftUI

/// One answer. Same 56 pt rhythm as the setup rows — the funnel and the app are
/// the same object. Selected = the frames' deep-red fill under a vermillon
/// hairline; nothing else changes, because the answer is the content, not the chrome.
struct OptionRow: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    private static let height: CGFloat = 56
    private static let selectedFillOpacity: Double = 0.35
    private static let selectedBorderWidth: CGFloat = 1.5

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack {
                Text(title)
                    .fudoFont(.body(16))
                    .foregroundStyle(FudoColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background {
                shape.fill(isSelected
                           ? FudoColor.accentDeep.opacity(Self.selectedFillOpacity)
                           : FudoColor.bgCard)
            }
            .overlay {
                shape.strokeBorder(isSelected ? FudoColor.accent : FudoColor.border,
                                   lineWidth: isSelected ? Self.selectedBorderWidth : 1)
            }
        }
        .buttonStyle(.plain)
        // Selection breathes at the house pace; DESELECTION snaps — otherwise
        // two rows read as selected while the old one fades (tester batch #1:
        // "the ONE thing" looked multi-select).
        .animation(isSelected ? AppAnimation.standard
                              : .easeOut(duration: OnboardingMetrics.optionDeselect),
                   value: isSelected)
    }
}
