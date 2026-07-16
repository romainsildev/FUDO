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
            // The chrome slot — back + bar render at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Monk Mode.\nYour rules.")
                        .fudoFont(.title(28, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                        .padding(.top, 48)

                    chipsRow
                        .padding(.top, 24)

                    presetLine
                        .padding(.top, 28)

                    // Affordance BEFORE the list, ultra-short (allègement
                    // 2026-07-16): two text lines max between chips and list.
                    Text("Tap a rule to edit.")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textPrimary)
                        .opacity(0.45)
                        .padding(.top, 10)

                    rulesList
                        .padding(.top, 16)

                    if setup.showRuleCountWarning {
                        Text("More rules = more failure.")
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.negative)
                            .padding(.top, 12)
                    }

                    // The CTA scrim dissolves the list's tail — the safeAreaInset
                    // already keeps the last row reachable, so just a breath here.
                    Spacer(minLength: 24)
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

    /// "MONK MODE 60 · RECOMMENDED FOR YOU" — the name comes from PresetCatalog,
    /// the ONE source (the frame's "CLASSIC" on a 30 d chip is a mock; reco = 60
    /// since 2026-07-16). Green here is the acted exception to the no-green rule.
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
        .padding(.top, 10)
        .padding(.bottom, 12)
        // Scrim, not a slab: the rows DISSOLVE under the button over ~40 pt
        // instead of being cut by a flat 0.94 edge.
        .background {
            LinearGradient(stops: [.init(color: FudoColor.bgPrimary.opacity(0), location: 0),
                                   .init(color: FudoColor.bgPrimary, location: 0.5)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#if DEBUG
#Preview("OB 11 — compose (recommended 60)") {
    OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: OnboardingPreviewFactory.viewModel(step: .compose))
    }
}

/// A chip he picked himself: the preset line drops the green "RECOMMENDED FOR
/// YOU" and shows the tagline instead, and the rules reload from the preset.
#Preview("OB 11 — compose (Monk Mode 120 picked)") {
    let viewModel = OnboardingPreviewFactory.viewModel(step: .compose)
    viewModel.setup.selectDuration(days: 120)
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
