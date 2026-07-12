import SwiftUI

/// One non-negotiable card. THIS session: simple tap toggles through GameStore
/// (the 1.5 s hold-to-check gesture replaces the tap in the next step — only the
/// gesture wiring changes, the card stays).
struct ChecklistRowView: View {
    let title: String
    let iconName: String
    let isChecked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconTile
                Text(title)
                    .font(FudoFont.body())
                    .strikethrough(isChecked, color: FudoColor.textSecondary)
                    .foregroundStyle(isChecked ? FudoColor.textSecondary : FudoColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                checkCircle
            }
            .padding(FudoSpacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
                    .strokeBorder(FudoColor.border, lineWidth: 1)
            }
            .opacity(isChecked ? 0.65 : 1)
            .contentShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isChecked ? "Checked" : "Not checked")
    }

    private var iconTile: some View {
        Image(systemName: iconName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(FudoColor.textPrimary)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                    .fill(FudoColor.bgPrimary)
            }
    }

    private var checkCircle: some View {
        ZStack {
            if isChecked {
                Circle().fill(FudoColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
            } else {
                Circle().strokeBorder(FudoColor.border, lineWidth: 1.5)
            }
        }
        .frame(width: 26, height: 26)
    }
}
