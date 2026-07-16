import SwiftUI

/// Full 3-screen setup flow (preset → rules → commit). Built as a reusable
/// component around the shared view model — NO in-app entry yet (decision
/// 2026-07-12): Home presents the standalone frame-04 cover; onboarding will
/// host the inline variant later.
struct ChallengeSetupFlowView: View {
    private enum Step: Hashable { case rules, confirm }

    @State private var viewModel: ChallengeSetupViewModel
    @State private var path: [Step] = []
    let onFinished: () -> Void

    init(store: GameStore, recommendedPreset: ChallengePreset = .monk60,
         onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: ChallengeSetupViewModel(store: store,
                                                                 recommendedPreset: recommendedPreset))
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationStack(path: $path) {
            PresetPickerScreen(viewModel: viewModel) { path.append(.rules) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .rules:
                        RulesEditorScreen(viewModel: viewModel) { path.append(.confirm) }
                    case .confirm:
                        LaunchConfirmScreen(viewModel: viewModel, onCommitted: onFinished)
                    }
                }
        }
        .tint(FudoColor.textSecondary)
    }
}
