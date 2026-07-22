import SwiftUI

/// A card's trailing badge — text + colour decided by the CALLER (11a owns the
/// ego bait): green is unique to the 60's "RECOMMENDED FOR YOU", the 120 baits
/// in vermillon. The card never invents a badge.
struct DurationBadge: Equatable {
    let text: String
    let color: Color
}

/// 11a's full-width duration card (batch #2, paywall-card pattern; batch #3:
/// parametric badge + "X days" trailing). `isProminent` = the recommended 60:
/// slightly larger, more padding. Selection is the vermillon hairline + deep
/// fill, same grammar as OptionRow.
struct DurationCard: View {
    let definition: PresetDefinition
    let isSelected: Bool
    var badge: DurationBadge?
    var isProminent: Bool = false
    let action: () -> Void

    private static let selectedFillOpacity: Double = 0.35
    private static let prominentScale: CGFloat = 1.03

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.title.uppercased())
                        .fudoFont(.headline(17))
                        .kerning(0.5)
                        .foregroundStyle(FudoColor.textPrimary)
                    Text(definition.tagline)
                        .fudoFont(.caption(13))
                        .foregroundStyle(FudoColor.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if let badge {
                        Text(badge.text)
                            .fudoFont(.label(9, weight: .bold))
                            .kerning(1)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(badge.color)
                    }
                    Text("\(definition.durationDays) days")
                        .fudoFont(.caption(12))
                        .foregroundStyle(FudoColor.textSecondary)
                }
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            .padding(.vertical, isProminent ? 18 : 14)
            .frame(maxWidth: .infinity)
            .background {
                shape.fill(isSelected
                           ? FudoColor.accentDeep.opacity(Self.selectedFillOpacity)
                           : FudoColor.bgCard)
            }
            .overlay {
                shape.strokeBorder(isSelected ? FudoColor.accent : FudoColor.border,
                                   lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isProminent ? Self.prominentScale : 1)
        .animation(AppAnimation.standard, value: isSelected)
    }
}
