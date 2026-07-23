import SwiftUI

/// OB 11b — the compose split's second half (tester batch #1, Romain): the
/// RULES. Up to here the app talked; here HE builds. A protocol you wrote
/// yourself is a protocol you don't walk away from: this is where the sunk
/// cost starts, and the signature is where it lands. The duration was locked
/// one screen earlier (11a) — one decision per screen.
///
/// The 4th skin of ONE view model. `ChallengeSetupStandaloneView` says it in its
/// own header — full flow, onboarding inline, standalone cover. Nothing about
/// presets or rules is re-implemented here: if logic is missing, it goes into
/// `ChallengeSetupViewModel`, never into this file.
struct ComposeProtocolScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var ruleSheet: RuleSheetMode?
    @State private var revealed = false

    private static let rowStagger: TimeInterval = 0.04
    private static let rulesDelay: TimeInterval = 0.15

    private var setup: ChallengeSetupViewModel { viewModel.setup }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — back + bar render at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Batch #2 header: the title and its qualifier share ONE
                    // line — "Your rules" carries, "pre-built" whispers. Two
                    // Texts on a baseline, never a concatenation: Text + Text
                    // needs frozen Fonts, the documented dead-scaling pitfall.
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("Your rules")
                            .fudoFont(.title(28, weight: .bold))
                            .foregroundStyle(FudoColor.textPrimary)
                        Text("— picked from your answers")
                            .fudoFont(.body(15))
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                    .padding(.top, 48)

                    Text("Tap to add or remove. Long press to edit.")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textPrimary)
                        .opacity(0.45)
                        .padding(.top, 10)

                    // The sweet-spot gauge (batch #12): the count, a bar that
                    // walks green (3-5) → red (7-8), and the line that hardens.
                    // It replaces the old lone warning — same copy, same ≥7 bite.
                    RuleLoadGauge(count: setup.enabledRules.count)
                        .padding(.top, 16)

                    rulesList
                        .padding(.top, 16)

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
        .sheet(item: $ruleSheet) { mode in
            RuleEditSheet(rule: mode.rule, viewModel: setup)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            viewModel.preparePersonalizedRules()
            revealed = true
        }
    }

    /// Two groups (batch #12): HIS protocol (enabled) on top, the rest of the
    /// catalog visible below — a tap moves a rule between the two. One ForEach
    /// per group over the SAME store array: toggling re-sorts, the spring
    /// carries the row across.
    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(setup.rules.filter(\.isEnabled).enumerated()),
                    id: \.element.id) { index, rule in
                ruleRow(rule, index: index)
            }
            AddRuleRow(isEnabled: setup.canAddRule) { ruleSheet = .add }

            let bench = setup.rules.filter { !$0.isEnabled }
            if !bench.isEmpty {
                Text("MORE RULES")
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 14)

                ForEach(Array(bench.enumerated()), id: \.element.id) { index, rule in
                    ruleRow(rule, index: index)
                }
            }
        }
        .animation(AppAnimation.spring, value: setup.rules.map(\.isEnabled))
    }

    private func ruleRow(_ rule: EditableRule, index: Int) -> some View {
        RuleRowEditor(rule: rule,
                      onToggle: { setup.toggleRule(id: rule.id) },
                      onEdit: { ruleSheet = .edit(rule) },
                      onDelete: { setup.removeRule(id: rule.id) })
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(AppAnimation.standard
                .delay(Self.rulesDelay + Double(index) * Self.rowStagger), value: revealed)
    }

    /// A TAP, not a hold. The standalone screen holds because it LAUNCHES the
    /// challenge; here the CTA only walks to the projection — the challenge is
    /// born at OB 19. The one hold of this funnel is the signature.
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

// MARK: - Sweet-spot gauge

/// The rule-load meter (batch #12): "N RULES" + a bar over the 8-rule cap +
/// one line that hardens as the protocol bloats. Colour is a VERDICT, not
/// decoration: green = the 3-5 sweet spot, vermilion = getting heavy (6),
/// red = the 7-8 failure zone. Under 3 the bar stays neutral — no judgement,
/// just not there yet.
private struct RuleLoadGauge: View {
    let count: Int

    private static let sweetSpot = 3...5

    private var fraction: CGFloat {
        CGFloat(min(count, GameConfig.maxRules)) / CGFloat(GameConfig.maxRules)
    }

    private var barColor: Color {
        switch count {
        case ..<Self.sweetSpot.lowerBound: return FudoColor.textSecondary
        case Self.sweetSpot: return FudoColor.positive
        case ChallengeSetupViewModel.ruleCountWarningThreshold...: return FudoColor.negative
        default: return FudoColor.accent
        }
    }

    private var line: String {
        switch count {
        case ..<Self.sweetSpot.lowerBound: return "3 — 5 rules is the sweet spot."
        case Self.sweetSpot: return "3 — 5 rules is the sweet spot. You're in it."
        default: return "More rules = more failure."
        }
    }

    private var lineHardens: Bool {
        count >= ChallengeSetupViewModel.ruleCountWarningThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(count)")
                    .fudoFont(.stat(22))
                    .foregroundStyle(FudoColor.textPrimary)
                Text(count == 1 ? "RULE" : "RULES")
                    .fudoFont(.label(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(FudoColor.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(FudoColor.border.opacity(0.6))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geometry.size.width * fraction))
                }
            }
            .frame(height: 4)

            Text(line)
                .fudoFont(.caption(12, weight: lineHardens ? .semibold : .regular))
                .foregroundStyle(lineHardens ? FudoColor.negative : FudoColor.textSecondary)
        }
        .animation(AppAnimation.standard, value: count)
    }
}

#if DEBUG
#Preview("OB 11b — rules (recommended 60)") {
    OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: OnboardingPreviewFactory.viewModel(step: .composeRules))
    }
}

/// Hardcore 90 ships 8 rules — the "More rules = more failure." warning fires
/// and the add row reads disabled at the cap.
#Preview("OB 11b — rules (Hardcore 90, warning)") {
    let viewModel = OnboardingPreviewFactory.viewModel(step: .composeRules)
    viewModel.setup.selectDuration(days: 90)
    return OnboardingPreviewChrome {
        ComposeProtocolScreen(viewModel: viewModel)
    }
}
#endif
