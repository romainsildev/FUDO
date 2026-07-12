import SwiftUI

/// Custom dark floating pill. Matches DesignReference/app 01/02/05/07:
/// every tab shows icon + label; active = vermillon icon+label inside a filled
/// highlight; inactive = grey (textSecondary), no fill. Pill = dark capsule + 1px border.
struct FudoTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tabButton($0) }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(FudoColor.bgCard)
                .overlay(Capsule().stroke(FudoColor.border, lineWidth: 1))
        )
        .animation(AppAnimation.standard, value: selected)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selected == tab
        return Button {
            Haptics.light()
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isActive ? FudoColor.accent : FudoColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(FudoColor.accent.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
