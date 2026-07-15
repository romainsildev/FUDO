import SwiftUI

/// OB 11 — the pivot of the whole funnel. Up to here the app talked; here HE
/// builds. A protocol you wrote yourself is a protocol you don't walk away from:
/// this is where the sunk cost starts, and the signature is where it lands.
///
/// The 4th skin of ONE view model. `ChallengeSetupStandaloneView` says it in its
/// own header — full flow, onboarding inline, standalone cover. Nothing about
/// presets or rules is re-implemented here: if logic is missing, it goes into
/// `ChallengeSetupViewModel`, never into this file.
struct ComposeProtocolScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var editedRule: EditableRule?
    @State private var isAddingRule = false
    @State private var revealed = false

    private static let rowStagger: TimeInterval = 0.04
    private static let rulesDelay: TimeInterval = 0.15

    private var setup: ChallengeSetupViewModel { viewModel.setup }

    /// Sheet routing: editing an existing rule vs composing a custom one.
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
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR PROTOCOL")
                        .fudoFont(.label(13, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FudoColor.accent)
                        .padding(.top, 48)

                    Text("Your Monk Mode.\nYour rules.")
                        .fudoFont(.title(28, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                        .padding(.top, 10)

                    chipsRow
                        .padding(.top, 24)

                    presetLine
                        .padding(.top, 28)

                    rulesList
                        .padding(.top, 12)

                    if setup.showRuleCountWarning {
                        Text("More rules = more failure.")
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.negative)
                            .padding(.top, 12)
                    }

                    Text("Tap a rule to adjust it. This is YOUR protocol.")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 16)

                    Spacer(minLength: 120)
                }
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { cta }
        .sheet(isPresented: sheetBinding) {
            RuleEditSheet(rule: editedRule, viewModel: setup)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            viewModel.prepareCompose()
            revealed = true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                viewModel.back()
            } label: {
                Image(systemName: "chevron.left")
                    .fudoFont(.headline())
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            OnboardingProgressBar(fraction: OnboardingStep.compose.progressFraction)
        }
        .frame(height: 24)
    }

    private var chipsRow: some View {
        HStack(spacing: 10) {
            ForEach(PresetCatalog.chipDays, id: \.self) { days in
                DurationChip(days: days, isSelected: setup.durationDays == days) {
                    setup.selectDuration(days: days)
                }
            }
        }
        .opacity(revealed ? 1 : 0)
    }

    /// "MONK MODE 30 · RECOMMENDED FOR YOU" — the name comes from PresetCatalog,
    /// the ONE source (the frame's "CLASSIC" on a 30 d chip is a mock).
    /// Green here is the acted exception to the no-green-accent rule.
    private var presetLine: some View {
        let definition = setup.definition
        let isRecommended = definition.preset == setup.recommendedPreset
        return Text(isRecommended
                    ? "\(definition.title.uppercased()) · RECOMMENDED FOR YOU"
                    : "\(definition.title.uppercased()) · \(definition.tagline.uppercased())")
            .fudoFont(.label(12, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(isRecommended ? FudoColor.positive : FudoColor.textSecondary)
    }

    private var rulesList: some View {
        VStack(spacing: 10) {
            ForEach(Array(setup.rules.enumerated()), id: \.element.id) { index, rule in
                RuleRowEditor(rule: rule,
                              onToggle: { setup.toggleRule(id: rule.id) },
                              onEdit: { editedRule = rule })
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 8)
                    .animation(AppAnimation.standard
                        .delay(Self.rulesDelay + Double(index) * Self.rowStagger), value: revealed)
            }
            AddRuleRow(isEnabled: setup.canAddRule) { isAddingRule = true }
        }
    }

    /// A TAP, not a hold. The standalone screen holds because it LAUNCHES the
    /// challenge; here the CTA only walks to the loader — the challenge is born
    /// at OB 19. The one hold of this funnel is the signature.
    private var cta: some View {
        Button(action: viewModel.advance) {
            Text("Lock my protocol")
                .fudoFont(.headline())
                .foregroundStyle(viewModel.canAdvance ? FudoColor.textPrimary : FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background {
                    Capsule().fill(viewModel.canAdvance ? FudoColor.accent : FudoColor.bgCard)
                }
                .overlay {
                    Capsule().strokeBorder(viewModel.canAdvance ? Color.clear : FudoColor.border,
                                           lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canAdvance)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
        .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
    }
}

#if DEBUG
#Preview("OB 11 — compose (recommended 30)") {
    OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: OnboardingPreviewFactory.viewModel(step: .compose))
    }
}

/// A chip he picked himself: the preset line drops the green "RECOMMENDED FOR
/// YOU" and shows the tagline instead, and the rules reload from the preset.
#Preview("OB 11 — compose (Classic 75 picked)") {
    let viewModel = OnboardingPreviewFactory.viewModel(step: .compose)
    viewModel.setup.selectDuration(days: 75)
    return OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: viewModel)
    }
}

/// Hardcore 90 ships 8 rules — the "More rules = more failure." warning fires.
#Preview("OB 11 — compose (Hardcore 90, warning)") {
    let viewModel = OnboardingPreviewFactory.viewModel(step: .compose)
    viewModel.setup.selectDuration(days: 90)
    return OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: viewModel)
    }
}
#endif
