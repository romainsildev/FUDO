import SwiftData
import SwiftUI

/// The funnel's container: one state machine, one switch, one transition rule.
/// Presented as a cover (no gesture dismiss) — the only exits are finishing it
/// or a kill, and a kill resumes where he stopped (OnboardingFlags.resumeStep).
struct OnboardingFlowView: View {
    @State private var viewModel: OnboardingViewModel
    /// Held for the screens that touch persistence directly — OB 15's one-shot
    /// review flag. Everything else goes through the view model.
    private let flags: OnboardingFlags

    init(store: GameStore, flags: OnboardingFlags = OnboardingFlags(),
         onFinished: @escaping () -> Void = {}) {
        self.flags = flags
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
                WelcomeScrim(isSplash: viewModel.step == .splash)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            content
                .transition(viewModel.transition)
        }
        .animation(AppAnimation.standard, value: viewModel.step)
    }

    // MARK: - Routing

    @ViewBuilder private var content: some View {
        @Bindable var viewModel = viewModel
        switch viewModel.step {

        // MARK: Act 0 — welcome

        case .splash:
            SplashScreen(onTap: viewModel.advance)
        case .transformation:
            WelcomeHookScreen(hook: .transformation, onAdvance: viewModel.advance)
        case .pain:
            WelcomeHookScreen(hook: .pain, onAdvance: viewModel.advance)
        case .mechanism:
            WelcomeHookScreen(hook: .mechanism, onAdvance: viewModel.advance)

        // MARK: Act 1 — diagnostic & self-persuasion
        //
        // The question and its options sit at the SAME call site: a table of
        // anonymous descriptors would hide what the user is actually asked.

        case .painPoint:
            SingleChoiceScreen(step: .painPoint, eyebrow: "START HERE",
                               title: "What's the ONE thing\nyou can't control alone?",
                               options: Pain.allCases, titleFor: \.optionTitle,
                               selection: $viewModel.draft.pain,
                               onAdvance: viewModel.advance, onBack: viewModel.back)
        case .scrollHours:
            SingleChoiceScreen(step: .scrollHours, eyebrow: "BE HONEST",
                               title: "How many hours a day\ndo you scroll?",
                               options: OnboardingAnswers.ScrollTime.allCases,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.scrollTime,
                               onAdvance: viewModel.advance, onBack: viewModel.back)
        case .age:
            SingleChoiceScreen(step: .age, eyebrow: "QUICK ONE",
                               title: "How old are you?",
                               options: AgeBracket.allCases, titleFor: \.optionTitle,
                               selection: $viewModel.draft.age,
                               onAdvance: viewModel.advance, onBack: viewModel.back)
        case .procrastination:
            SingleChoiceScreen(step: .procrastination, eyebrow: "NO JUDGMENT",
                               title: "How often do you say\n\"I'll start Monday\"?",
                               // Frame order (worst first) — NOT allCases, which
                               // is ordered by the OVR scale.
                               options: OnboardingAnswers.Procrastination.displayOrder,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.procrastination,
                               onAdvance: viewModel.advance, onBack: viewModel.back)
        case .shockStat:
            if let shock = viewModel.shock, let pain = viewModel.draft.pain {
                ShockStatScreen(shock: shock, pain: pain,
                                onAdvance: viewModel.advance, onBack: viewModel.back)
            }
        case .goals:
            MultiChoiceScreen(step: .goals, eyebrow: "YOUR TARGETS",
                              title: "What do you actually\nwant?",
                              subtitle: "Pick all that apply",
                              options: Goal.allCases,
                              selection: $viewModel.draft.goals,
                              onAdvance: viewModel.advance, onBack: viewModel.back)
        case .struggle:
            SingleChoiceScreen(step: .struggle, eyebrow: "THE REAL TALK",
                               title: "What's your real problem?",
                               options: OnboardingAnswers.Struggle.allCases,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.struggle,
                               onAdvance: viewModel.advance, onBack: viewModel.back)
        case .reflection:
            if let struggle = viewModel.draft.struggle {
                ReflectionScreen(goals: viewModel.draft.goals, pain: viewModel.draft.pain,
                                 struggle: struggle, onAdvance: viewModel.advance)
            }
        case .diagnostic:
            DiagnosticScreen(ovr: viewModel.diagnosticOVR, rank: viewModel.diagnosticRank,
                             onAdvance: viewModel.advance, onBack: viewModel.back)

        // MARK: Act 2 — climax

        case .compose:
            ComposeProtocolScreen(viewModel: viewModel)
        case .loaderBuilding:
            OnboardingLoaderScreen(
                title: "Building your protocol…",
                steps: ["Reading your weak spot",
                        "Calibrating your daily rules",
                        "Setting your start — OVR \(viewModel.diagnosticOVR)",
                        "Projecting your \(viewModel.setup.durationDays)-day climb"],
                footer: "Locking in your numbers. A few seconds.",
                duration: OnboardingMetrics.buildLoaderDuration,
                onFinished: viewModel.advance)
        case .projection:
            ProjectionScreen(base: OVREngine.startingOVR(from: viewModel.draft.answers),
                             days: viewModel.setup.durationDays,
                             projectedOVR: viewModel.projectedOVR,
                             projectedRank: viewModel.projectedRank,
                             date: viewModel.projectionDate,
                             onAdvance: viewModel.advance, onBack: viewModel.back)
        case .firstCheck:
            FirstCheckScreen(onAdvance: viewModel.advance)
        case .socialProof:
            SocialProofScreen(flags: flags, onAdvance: viewModel.advance)

        // MARK: Act 3 — engagement, contract, paywall

        case .commitment:
            CommitmentScreen(selection: $viewModel.draft.commitment, onAdvance: viewModel.advance)
        case .contract:
            ContractScreen(startingOVR: viewModel.diagnosticOVR,
                           rank: viewModel.diagnosticRank,
                           projectedOVR: OVREngine.displayedOVR(viewModel.projectedOVR),
                           projectedRank: viewModel.projectedRank,
                           date: viewModel.projectionDate,
                           durationDays: viewModel.setup.durationDays,
                           hasSignature: viewModel.hasSignature,
                           onSign: viewModel.signContract,
                           onSignatureStroke: viewModel.registerSignature)
        case .paywall:
            PaywallGateView(contract: flags.contract, date: viewModel.projectionDate,
                            onContinue: viewModel.passPaywall)

        default:
            // Act 4 lands here, screen by screen.
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
/// The whole funnel, walkable from OB 00. Every other screen has its own
/// #Preview; this one is for the transitions between them.
/// Container + store come from OnboardingPreviewFactory — ONE per process.
#Preview("Onboarding — full funnel") {
    OnboardingFlowView(store: OnboardingPreviewFactory.store,
                       flags: OnboardingPreviewFactory.flags())
        .preferredColorScheme(.dark)
}
#endif
