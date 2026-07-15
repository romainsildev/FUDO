#if DEBUG
import SwiftUI

/// Settings §DEBUG — device escape hatches while the real flows aren't built
/// (abandon ships with the Settings session). Every action goes through
/// GameStore, never a direct mutation; Today reflects the result live.
/// The whole file is DEBUG-only: invisible in Release.
struct DebugMenuSection: View {
    @Environment(GameStore.self) private var store
    @State private var pendingAction: DebugAction?

    private enum DebugAction: String, CaseIterable, Identifiable {
        case wipeAndReseed, wipeBlank, completeChallenge, abandonChallenge

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wipeAndReseed: return "Wipe & reseed"
            case .wipeBlank: return "Wipe vierge"
            case .completeChallenge: return "Complete challenge"
            case .abandonChallenge: return "Abandon challenge"
            }
        }

        var detail: String {
            switch self {
            case .wipeAndReseed: return "Erase everything, replay the day-12 seed."
            case .wipeBlank: return "Erase everything, stay blank (no auto-seed)."
            case .completeChallenge: return "End the active challenge as completed."
            case .abandonChallenge: return "Abandon with the normal penalty."
            }
        }

        var needsActiveChallenge: Bool {
            switch self {
            case .completeChallenge, .abandonChallenge: return true
            case .wipeAndReseed, .wipeBlank: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG")
                .fudoFont(.label(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(FudoColor.textSecondary)

            ForEach(DebugAction.allCases) { action in
                Button {
                    pendingAction = action
                } label: {
                    HStack {
                        Text(action.label)
                            .fudoFont(.body(15))
                            .foregroundStyle(FudoColor.textPrimary)
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .fudoFont(.glyph(12))
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                    .padding(.horizontal, FudoSpacing.cardPadding)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                            .fill(FudoColor.bgCard)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                            .strokeBorder(FudoColor.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(action.needsActiveChallenge && store.activeChallenge == nil)
                .opacity(action.needsActiveChallenge && store.activeChallenge == nil ? 0.4 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(pendingAction?.label ?? "",
                            isPresented: Binding(get: { pendingAction != nil },
                                                 set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingAction) { action in
            Button(action.label, role: .destructive) { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.detail)
        }
    }

    private func perform(_ action: DebugAction) {
        switch action {
        case .wipeAndReseed: store.debugWipe(reseed: true)
        case .wipeBlank: store.debugWipe(reseed: false)
        case .completeChallenge: store.debugCompleteActiveChallenge()
        case .abandonChallenge: store.abandonChallenge()
        }
    }
}
#endif
