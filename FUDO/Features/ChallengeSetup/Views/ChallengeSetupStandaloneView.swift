import SwiftUI

/// Standalone challenge setup — frame 04, presented as a full-screen cover from
/// the Home no-challenge CTA (and later from Challenge-complete). Duration CHIPS,
/// not preset cards: maquette followed over PRD 04 (divergence logged 2026-07-11).
/// No gesture dismiss — back and a successful commit are the only exits.
struct ChallengeSetupStandaloneView: View {
    @State private var viewModel: ChallengeSetupViewModel
    @State private var ruleSheet: RuleSheetMode?
    let onExit: () -> Void

    init(store: GameStore, recommendedPreset: ChallengePreset = .monk60,
         onExit: @escaping () -> Void) {
        _viewModel = State(initialValue: ChallengeSetupViewModel(store: store,
                                                                 recommendedPreset: recommendedPreset))
        self.onExit = onExit
    }

    var body: some View {
        VStack(spacing: 0) {
            navHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR PROTOCOL")
                        .fudoFont(.label(13, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FudoColor.accent)
                        .padding(.top, 16)

                    Text("Your Monk Mode.\nYour rules.")
                        .fudoFont(.title(32))
                        .foregroundStyle(FudoColor.textPrimary)
                        .padding(.top, 8)

                    chipsRow
                        .padding(.top, 24)

                    presetLine
                        .padding(.top, 28)

                    rulesList
                        .padding(.top, 12)

                    if viewModel.showRuleCountWarning {
                        Text("More rules = more failure.")
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.negative)
                            .padding(.top, 12)
                    }

                    Text("Tap to toggle, hold to edit. This is YOUR protocol.")
                        .fudoFont(.caption())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.top, 16)

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, FudoSpacing.screenMargin)
            }
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { startCTA }
        .sheet(item: $ruleSheet) { mode in
            RuleEditSheet(rule: mode.rule, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var navHeader: some View {
        ZStack {
            Text("New challenge")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
            HStack {
                Button {
                    Haptics.light()
                    onExit()
                } label: {
                    Image(systemName: "chevron.left")
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Chips + preset line

    private var chipsRow: some View {
        HStack(spacing: 10) {
            ForEach(PresetCatalog.chipDays, id: \.self) { days in
                DurationChip(days: days,
                             isSelected: viewModel.durationDays == days) {
                    viewModel.selectDuration(days: days)
                }
            }
        }
    }

    /// "MONK MODE 30 · RECOMMENDED FOR YOU" — frame 04 uses green here; assumed
    /// exception to the no-green-accent rule, flagged to Romain in the spec.
    private var presetLine: some View {
        let definition = viewModel.definition
        let isRecommended = definition.preset == viewModel.recommendedPreset
        return Text(isRecommended
                    ? "\(definition.title.uppercased()) · RECOMMENDED FOR YOU"
                    : "\(definition.title.uppercased()) · \(definition.tagline.uppercased())")
            .fudoFont(.label(12, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(isRecommended ? FudoColor.positive : FudoColor.textSecondary)
    }

    // MARK: - Rules

    private var rulesList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.rules) { rule in
                RuleRowEditor(rule: rule,
                              onToggle: { viewModel.toggleRule(id: rule.id) },
                              onEdit: { ruleSheet = .edit(rule) },
                              onDelete: { viewModel.removeRule(id: rule.id) })
            }
            AddRuleRow(isEnabled: viewModel.canAddRule) { ruleSheet = .add }
        }
    }

    // MARK: - CTA

    private var startCTA: some View {
        Text("Start challenge — Day 1")
            .fudoFont(.headline())
            .foregroundStyle(FudoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: FudoSpacing.ctaHeight)
            .background { Capsule().fill(viewModel.canCommit ? FudoColor.accent : FudoColor.bgCard) }
            .overlay {
                Capsule().strokeBorder(viewModel.canCommit ? Color.clear : FudoColor.border,
                                       lineWidth: 1)
            }
            .holdToConfirm(in: Capsule(), completionHaptic: .heavy,
                           ringColor: FudoColor.textPrimary) { start() }
            .disabled(!viewModel.canCommit)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background {
                FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom)
            }
    }

    /// Let the sealed ring + heavy haptic land before the cover drops to day 1.
    private func start() {
        guard viewModel.commit() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(HoldToConfirmMetrics.sealResetDelay))
            onExit()
        }
    }
}
