import SwiftUI

/// One rule row at setup: icon + title, trailing enable circle. Tapping the body
/// opens the edit sheet; tapping the circle toggles the rule in place.
struct RuleRowEditor: View {
    let rule: EditableRule
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: rule.iconName)
                    .fudoFont(.glyph(17, weight: .medium))
                    .foregroundStyle(rule.isEnabled ? FudoColor.textPrimary : FudoColor.textSecondary)
                    .frame(width: 28)

                Text(rule.title)
                    .fudoFont(.body(16))
                    .foregroundStyle(rule.isEnabled ? FudoColor.textPrimary : FudoColor.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                enableCircle
            }
            .padding(.horizontal, FudoSpacing.cardPadding)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(FudoColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var enableCircle: some View {
        Button {
            Haptics.light()
            onToggle()
        } label: {
            ZStack {
                Circle()
                    .fill(rule.isEnabled ? FudoColor.accent : Color.clear)
                Circle()
                    .strokeBorder(rule.isEnabled ? Color.clear : FudoColor.border, lineWidth: 1.5)
                if rule.isEnabled {
                    Image(systemName: "checkmark")
                        .fudoFont(.glyph(11, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
            .frame(width: 24, height: 24)
            .animation(AppAnimation.standard, value: rule.isEnabled)
        }
        .buttonStyle(.plain)
    }
}
