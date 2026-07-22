import SwiftUI

/// One rule row at setup. Tester batch #1 (2026-07-16): the whole row IS the
/// toggle — a 24 pt circle was too small a target for the row's one action.
/// Editing and deleting moved to a native context menu (long-press); the
/// trailing circle is now purely the state's face, not its own button.
struct RuleRowEditor: View {
    let rule: EditableRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            onToggle()
        } label: {
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
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .accessibilityValue(rule.isEnabled ? "On" : "Off")
        .accessibilityHint("Double tap to toggle. Long press to edit or delete.")
    }

    private var enableCircle: some View {
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
}
