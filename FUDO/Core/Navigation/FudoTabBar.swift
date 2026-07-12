import SwiftUI

/// Floating glass pill tab bar — RiteOff recipe, FUDO colors. Content-hugging
/// tabs: every tab shows icon + label; active = vermillon icon+label over a
/// `surfaceGlassStrong` capsule; inactive = grey (textSecondary), no fill.
/// Pill = frosted glass (``FudoGlassCapsule``) so it reads over both flat ink
/// and the warm-gradient screens.
struct FudoTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { tabButton($0) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .fudoGlassCapsule()
        .animation(AppAnimation.standard, value: selected)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let active = (selected == tab)
        return Button {
            guard selected != tab else { return }
            Haptics.light()
            selected = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(active ? FudoColor.accent : FudoColor.textSecondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .frame(minWidth: 84)
            .background {
                if active {
                    Capsule().fill(FudoColor.surfaceGlassStrong)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
