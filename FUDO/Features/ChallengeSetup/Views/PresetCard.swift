import SwiftUI

/// Vertical preset card (full flow screen 1): title, duration, tagline, rule
/// count — the recommended one wears the "Recommended for you" badge.
struct PresetCard: View {
    let definition: PresetDefinition
    let isRecommended: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if isRecommended {
                    Text("RECOMMENDED FOR YOU")
                        .fudoFont(.label(11, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(FudoColor.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(FudoColor.accentDeep) }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(definition.title)
                        .fudoFont(.title(20))
                        .foregroundStyle(FudoColor.textPrimary)
                    Spacer()
                    Text("\(definition.durationDays) days")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textSecondary)
                }

                Text(definition.tagline)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)

                Text("\(definition.defaultRules.count) rules")
                    .fudoFont(.caption())
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FudoSpacing.cardPaddingMajor)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(isSelected ? FudoColor.accent : FudoColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standard, value: isSelected)
    }
}
