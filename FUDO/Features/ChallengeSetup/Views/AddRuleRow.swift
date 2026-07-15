import SwiftUI

/// Dashed ghost row "＋ Add rule" (frame 04). Disabled look at the 8-rule cap.
struct AddRuleRow: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .fudoFont(.body(14, weight: .semibold))
                Text("Add rule")
                    .fudoFont(.body(15))
            }
            .foregroundStyle(FudoColor.textSecondary.opacity(isEnabled ? 1 : 0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(FudoColor.border.opacity(isEnabled ? 1 : 0.5),
                                  style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
