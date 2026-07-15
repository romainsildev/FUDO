import SwiftUI

/// Custom 7d / 30d / challenge segmented control. Token-styled (never the system
/// `.segmented` picker — that's blue). Selected segment is a raised glass pill that
/// slides under the label; a light haptic fires on change. Used on both the Stats
/// tab and — inheriting the same selection — the Habit detail.
struct StatsPeriodPicker: View {
    @Binding var period: StatsPeriod
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases, id: \.self) { option in
                segment(option)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func segment(_ option: StatsPeriod) -> some View {
        let selected = option == period
        return Text(option.label)
            .fudoFont(.label(12, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(selected ? FudoColor.textPrimary : FudoColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if selected {
                    Capsule()
                        .fill(FudoColor.surfaceGlassStrong)
                        .overlay(Capsule().strokeBorder(FudoColor.borderGlass, lineWidth: 0.5))
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
            .onTapGesture {
                guard !selected else { return }
                Haptics.light()
                withAnimation(AppAnimation.standard) { period = option }
            }
            .accessibilityElement()
            .accessibilityLabel(option.label)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
