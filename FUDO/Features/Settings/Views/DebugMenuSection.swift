#if DEBUG
import SwiftUI

/// Settings §DEBUG — device escape hatches while the real flows aren't built
/// (abandon ships with the Settings session). Every action goes through
/// GameStore, never a direct mutation; Today reflects the result live.
/// The whole file is DEBUG-only: invisible in Release.
struct DebugMenuSection: View {
    @Environment(GameStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements: EntitlementStore?
    @State private var pendingAction: DebugAction?

    private enum DebugAction: String, CaseIterable, Identifiable {
        case wipeAndReseed, wipeBlank, replayOnboarding, triggerRankUp, completeChallenge, abandonChallenge

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wipeAndReseed: return "Wipe & reseed"
            case .wipeBlank: return "Wipe vierge"
            case .replayOnboarding: return "Replay onboarding"
            case .triggerRankUp: return "Trigger rank-up"
            case .completeChallenge: return "Complete challenge"
            case .abandonChallenge: return "Abandon challenge"
            }
        }

        var detail: String {
            switch self {
            case .wipeAndReseed: return "Erase everything, replay the day-12 seed."
            case .wipeBlank: return "Erase everything, stay blank (no auto-seed)."
            case .replayOnboarding: return "Erase everything INCLUDING the player, replay the funnel from OB 00."
            case .triggerRankUp: return "Present the rank-up cover for the current rank."
            case .completeChallenge: return "End the active challenge as completed."
            case .abandonChallenge: return "Abandon with the normal penalty."
            }
        }

        var needsActiveChallenge: Bool {
            switch self {
            case .completeChallenge, .abandonChallenge: return true
            case .wipeAndReseed, .wipeBlank, .replayOnboarding, .triggerRankUp: return false
            }
        }
    }

    var body: some View {
        // No own header: the real Settings screen (S10) wraps this in a Section
        // that already carries the "DEBUG" header — two were showing.
        VStack(alignment: .leading, spacing: 10) {
            if let entitlements {
                EntitlementOverrideRow(entitlements: entitlements)
            }

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
        case .replayOnboarding:
            store.debugReplayOnboarding()
            // RootView only re-routes on scene-active; flipping the flag it watches
            // raises the cover now, instead of making you background the app.
            appState.hasCompletedOnboarding = false
        case .triggerRankUp: store.debugTriggerRankUp()
        case .completeChallenge: store.debugCompleteActiveChallenge()
        case .abandonChallenge: store.abandonChallenge()
        }
    }
}

/// Segmented entitlement override — System follows RevenueCat, Pro/Free force
/// the gate. Free simulates the expired-trial paywall over Home without any
/// purchase (the sandbox stays dead until the banking paperwork clears); the
/// escape back lives on the paywall itself, since this menu sits under it.
private struct EntitlementOverrideRow: View {
    let entitlements: EntitlementStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entitlement override")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textPrimary)

            Picker("Entitlement override", selection: selection) {
                Text("System").tag(0)
                Text("Pro").tag(1)
                Text("Free").tag(2)
            }
            .pickerStyle(.segmented)

            Text("Free raises the expired-trial paywall over the whole app.")
                .fudoFont(.caption(11))
                .foregroundStyle(FudoColor.textSecondary)

            Toggle(isOn: trialConsumedBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trial already consumed")
                        .fudoFont(.body(15))
                        .foregroundStyle(FudoColor.textPrimary)
                    Text("Paywall drops every trial promise — price only. Reopen the paywall to see it.")
                        .fudoFont(.caption(11))
                        .foregroundStyle(FudoColor.textSecondary)
                }
            }
            .tint(FudoColor.accent)
            .padding(.top, 6)
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: {
                switch entitlements.debugProOverride {
                case .some(true): return 1
                case .some(false): return 2
                case .none: return 0
                }
            },
            set: { value in
                switch value {
                case 1: entitlements.debugProOverride = true
                case 2: entitlements.debugProOverride = false
                default: entitlements.debugProOverride = nil
                }
            })
    }

    private var trialConsumedBinding: Binding<Bool> {
        Binding(
            get: { entitlements.debugTrialConsumed },
            set: { entitlements.debugTrialConsumed = $0 })
    }
}
#endif
