import SwiftUI

/// Full-flow screen 2: the preset's rules — toggle, edit, add custom (cap 8,
/// warning line from the 7th). Same rows and sheet as the standalone skin.
struct RulesEditorScreen: View {
    let viewModel: ChallengeSetupViewModel
    let onNext: () -> Void

    @State private var editedRule: EditableRule?
    @State private var isAddingRule = false

    private var sheetBinding: Binding<Bool> {
        Binding(get: { editedRule != nil || isAddingRule },
                set: { presented in
                    if !presented {
                        editedRule = nil
                        isAddingRule = false
                    }
                })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adjust your rules")
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 16)

                Text("Every rule is daily. Tap to edit, toggle to drop.")
                    .font(FudoFont.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.bottom, 10)

                ForEach(viewModel.rules) { rule in
                    RuleRowEditor(rule: rule,
                                  onToggle: { viewModel.toggleRule(id: rule.id) },
                                  onEdit: { editedRule = rule })
                }

                AddRuleRow(isEnabled: viewModel.canAddRule) { isAddingRule = true }

                if viewModel.showRuleCountWarning {
                    Text("More rules = more failure.")
                        .font(FudoFont.caption())
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
                    .font(.system(size: 17, weight: .semibold))
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
        .sheet(isPresented: sheetBinding) {
            RuleEditSheet(rule: editedRule, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("")
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
    }
}
