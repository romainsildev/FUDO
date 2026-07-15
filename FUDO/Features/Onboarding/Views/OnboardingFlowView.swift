import SwiftData
import SwiftUI

/// The funnel's container: one state machine, one switch, one transition rule.
/// Presented as a cover (no gesture dismiss) — the only exits are finishing it
/// or a kill, and a kill resumes where he stopped (OnboardingFlags.resumeStep).
struct OnboardingFlowView: View {
    @State private var viewModel: OnboardingViewModel

    init(store: GameStore, flags: OnboardingFlags = OnboardingFlags(),
         onFinished: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: OnboardingViewModel(store: store, flags: flags,
                                                             onFinished: onFinished))
    }

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()

            // ONE stage for the whole welcome act — the screens cross-fade OVER it,
            // so the motion never restarts between 00 → 01a → 01b → 01c.
            if viewModel.step.isWelcome {
                WelcomeStageView(clip: viewModel.welcomeClip)
                    .ignoresSafeArea()
                    .transition(.opacity)
                welcomeScrim
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            content
                .transition(viewModel.transition)
        }
        .animation(AppAnimation.standard, value: viewModel.step)
    }

    // MARK: - Scrim
    //
    // Two layers, always BETWEEN the video and the text: a vertical wash so the
    // copy holds on any frame, and the focus vignette the brief asks for. The
    // splash reinforces it — it's a focal point, not a set.

    private var welcomeScrim: some View {
        ZStack {
            LinearGradient(colors: [FudoColor.bgPrimary.opacity(0.35),
                                    FudoColor.bgPrimary.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.clear, FudoColor.bgPrimary.opacity(isSplash ? 0.85 : 0.75)],
                           center: .center,
                           startRadius: isSplash ? 60 : 120,
                           endRadius: 420)
        }
        .allowsHitTesting(false)
    }

    private var isSplash: Bool { viewModel.step == .splash }

    // MARK: - Routing

    @ViewBuilder private var content: some View {
        switch viewModel.step {
        case .splash:
            SplashScreen(onTap: viewModel.advance)
        case .transformation:
            WelcomeHookScreen(hook: .transformation, onAdvance: viewModel.advance)
        case .pain:
            WelcomeHookScreen(hook: .pain, onAdvance: viewModel.advance)
        case .mechanism:
            WelcomeHookScreen(hook: .mechanism, onAdvance: viewModel.advance)
        default:
            // Acts 1-4 land here, screen by screen.
            actUnderConstruction
        }
    }

    /// Temporary — replaced screen by screen as the acts land. Never shipped:
    /// the funnel is not routable until OnboardingFlags gates it (Task 21).
    private var actUnderConstruction: some View {
        VStack(spacing: 12) {
            Text("\(String(describing: viewModel.step))")
                .fudoFont(.title(24, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
            Button("Continue", action: viewModel.advance)
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.accent)
        }
    }
}

#if DEBUG
/// Pattern acté 2026-07-15: the factory OWNS the container in a `static let` —
/// `container.mainContext` does not retain it, and a deallocated container makes
/// SwiftData reset the context mid-preview ("destroyed by ModelContext.reset").
@MainActor
private enum OnboardingPreviewFactory {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // ONE shared Schema — never the variadic ModelContainer(for:) initializer
        // (iOS 17 duplicate-metadata crash, carnet 2026-07-12).
        guard let container = try? ModelContainer(for: FudoSchema.schema,
                                                  configurations: configuration) else {
            fatalError("preview container")
        }
        return container
    }()

    /// No player, no challenge — the state the funnel actually runs against.
    static let store = GameStore(modelContext: container.mainContext)

    static let flags = OnboardingFlags(
        defaults: UserDefaults(suiteName: "preview.onboarding") ?? .standard)
}

#Preview("Onboarding — full funnel") {
    OnboardingFlowView(store: OnboardingPreviewFactory.store,
                       flags: OnboardingPreviewFactory.flags)
        .preferredColorScheme(.dark)
}
#endif
