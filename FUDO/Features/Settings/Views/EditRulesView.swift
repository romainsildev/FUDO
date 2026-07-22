import SwiftUI

/// Settings → Edit rules. Reachable only while the challenge is ≤ day 3 (the
/// caller gates on `canEditActiveRules`). Reuses the setup skin's row + sheet by
/// driving a `ChallengeSetupViewModel` purely as a rule editor, then commits the
/// reconciled set through `GameStore.editActiveChallengeRules` — NOT `startChallenge`.
struct EditRulesView: View {
    private let store: GameStore
    @State private var editor: ChallengeSetupViewModel
    @State private var ruleSheet: RuleSheetMode?
    @Environment(\.dismiss) private var dismiss

    init(store: GameStore) {
        self.store = store
        let vm = ChallengeSetupViewModel(store: store)
        vm.rules = Self.seedRules(from: store.activeChallenge)
        _editor = State(initialValue: vm)
    }

    /// TaskRule → EditableRule, preserving id (so the reconcile matches) and the
    /// enabled state. Time rules are detected by their sunrise glyph — the minute
    /// value isn't stored on TaskRule (baked into the title), so re-picking a time
    /// restarts from the default; renaming always works.
    private static func seedRules(from challenge: Challenge?) -> [EditableRule] {
        (challenge?.rules ?? []).sorted { $0.sortOrder < $1.sortOrder }.map { rule in
            EditableRule(id: rule.id,
                         title: rule.title,
                         iconName: rule.iconName,
                         isEnabled: rule.isActive,
                         domain: rule.domain,
                         valueKind: rule.iconName == "sunrise.fill" ? .time : .plain)
        }
    }

    private var canSave: Bool { !editor.enabledRules.isEmpty && store.canEditActiveRules }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tap to toggle, hold to edit. Locked after day \(GameConfig.rulesLockDay).")
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                ForEach(editor.rules) { rule in
                    RuleRowEditor(rule: rule,
                                  onToggle: { editor.toggleRule(id: rule.id) },
                                  onEdit: { ruleSheet = .edit(rule) },
                                  onDelete: { editor.removeRule(id: rule.id) })
                }

                AddRuleRow(isEnabled: editor.canAddRule) { ruleSheet = .add }

                if editor.showRuleCountWarning {
                    Text("More rules = more failure.")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.negative)
                        .padding(.top, 6)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.medium()
                save()
            } label: {
                Text("Save changes")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(canSave ? FudoColor.accent : FudoColor.bgCard) }
                    .overlay {
                        Capsule().strokeBorder(canSave ? Color.clear : FudoColor.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
        }
        .sheet(item: $ruleSheet) { mode in
            RuleEditSheet(rule: mode.rule, viewModel: editor)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("Edit rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
        .fudoHidesTabBar()
    }

    private func save() {
        let edits = editor.rules.map {
            RuleEdit(id: $0.id, title: $0.title, iconName: $0.iconName,
                     domain: $0.domain, isEnabled: $0.isEnabled)
        }
        store.editActiveChallengeRules(edits)
        dismiss()
    }
}
