import SwiftUI

/// Frame-04 duration chip ("30 d") — selected = vermillon fill, idle = card.
/// `isRecommended` (OB 11 nudge, 2026-07-16): while it is NOT selected, the
/// recommended chip whispers in `positive` — a 1.5 pt hairline and its label,
/// nothing else. Selected, it behaves exactly like any chip (vermillon fill).
struct DurationChip: View {
    let days: Int
    let isSelected: Bool
    var isRecommended: Bool = false
    let action: () -> Void

    private var nudges: Bool { isRecommended && !isSelected }

    var body: some View {
        Button {
            action()
        } label: {
            Text("\(days) d")
                .fudoFont(.headline(16))
                .foregroundStyle(nudges ? FudoColor.positive : FudoColor.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background {
                    Capsule().fill(isSelected ? FudoColor.accent : FudoColor.bgCard)
                }
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : (nudges ? FudoColor.positive : FudoColor.border),
                        lineWidth: nudges ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standard, value: isSelected)
    }
}
