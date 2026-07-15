import SwiftUI

/// Frame-04 duration chip ("30 d") — selected = vermillon fill, idle = card.
struct DurationChip: View {
    let days: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text("\(days) d")
                .fudoFont(.headline(16))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background {
                    Capsule().fill(isSelected ? FudoColor.accent : FudoColor.bgCard)
                }
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : FudoColor.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standard, value: isSelected)
    }
}
