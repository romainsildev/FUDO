import SwiftUI

/// Full-flow screen 2: the preset's rules — toggle, edit, add custom (cap 8,
/// warning line from the 7th). Same rows and sheet as the standalone skin.
struct RulesEditorScreen: View {
    let viewModel: ChallengeSetupViewModel
    let onNext: () -> Void

    @State private var ruleSheet: RuleSheetMode?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adjust your rules")
                    .fudoFont(.title())
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 16)

                Text("Every rule is daily. Tap to toggle, hold to edit.")
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.bottom, 10)

                ForEach(viewModel.rules) { rule in
                    RuleRowEditor(rule: rule,
                                  onToggle: { viewModel.toggleRule(id: rule.id) },
                                  onEdit: { ruleSheet = .edit(rule) },
                                  onDelete: { viewModel.removeRule(id: rule.id) })
                }

                AddRuleRow(isEnabled: viewModel.canAddRule) { ruleSheet = .add }

                if viewModel.showRuleCountWarning {
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
                onNext()
            } label: {
                Text("Continue")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(viewModel.canCommit ? FudoColor.accent : FudoColor.bgCard) }
                    .overlay {
                        Capsule().strokeBorder(viewModel.canCommit ? Color.clear : FudoColor.border,
                                               lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCommit)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
        }
        .sheet(item: $ruleSheet) { mode in
            RuleEditSheet(rule: mode.rule, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("")
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
    }
}
