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

            // Stable chrome (UX pass 2026-07-16): the bar and the chevron sit
            // ABOVE the sliding screens, so the bar only fills — it never slides
            // in with a screen. Screens keep an empty slot where it renders.
            if viewModel.step.showsProgress {
                OnboardingChromeHeader(step: viewModel.step, onBack: viewModel.back)
                    .transition(.opacity)
            }
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
            SingleChoiceScreen(step: .painPoint, 
                               title: "What's the ONE thing\nyou can't control alone?",
                               options: Pain.allCases, titleFor: \.optionTitle,
                               selection: $viewModel.draft.pain,
                               onAdvance: viewModel.advance)
        case .scrollHours:
            SingleChoiceScreen(step: .scrollHours, 
                               title: "How many hours a day\ndo you scroll?",
                               options: OnboardingAnswers.ScrollTime.allCases,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.scrollTime,
                               onAdvance: viewModel.advance)
        case .age:
            SingleChoiceScreen(step: .age, 
                               title: "How old are you?",
                               options: AgeBracket.allCases, titleFor: \.optionTitle,
                               selection: $viewModel.draft.age,
                               onAdvance: viewModel.advance)
        case .procrastination:
            SingleChoiceScreen(step: .procrastination, 
                               title: "How often do you say\n\"I'll start Monday\"?",
                               // Frame order (worst first) — NOT allCases, which
                               // is ordered by the OVR scale.
                               options: OnboardingAnswers.Procrastination.displayOrder,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.procrastination,
                               onAdvance: viewModel.advance)
        case .shockStat:
            if let shock = viewModel.shock, let pain = viewModel.draft.pain {
                ShockStatScreen(shock: shock, pain: pain,
                                onAdvance: viewModel.advance)
            }
        case .goals:
            MultiChoiceScreen(step: .goals, 
                              title: "What do you actually\nwant?",
                              subtitle: "Pick all that apply",
                              options: Goal.allCases,
                              selection: $viewModel.draft.goals,
                              onAdvance: viewModel.advance)
        case .struggle:
            SingleChoiceScreen(step: .struggle, 
                               title: "What's your real problem?",
                               options: OnboardingAnswers.Struggle.allCases,
                               titleFor: \.optionTitle,
                               selection: $viewModel.draft.struggle,
                               onAdvance: viewModel.advance)
        case .reflection:
            if let struggle = viewModel.draft.struggle {
                ReflectionScreen(goals: viewModel.draft.goals, pain: viewModel.draft.pain,
                                 struggle: struggle, onAdvance: viewModel.advance)
            }
        case .diagnostic:
            DiagnosticScreen(ovr: viewModel.diagnosticOVR, rank: viewModel.diagnosticRank,
                             onAdvance: viewModel.advance)

        // MARK: Act 2 — climax

        case .compose:
            ComposeProtocolScreen(viewModel: viewModel)
        case .loaderBuilding:
            // Narrative loader (RiteOff model, 2026-07-16): HIS stats orbit the
            // ring, then HE taps "Access your report" — no auto-advance.
            BuildLoaderScreen(
                stats: OnboardingCopy.buildLoaderStats(draft: viewModel.draft,
                                                       ovr: viewModel.diagnosticOVR,
                                                       days: viewModel.setup.durationDays),
                steps: ["Reading your weak spot",
                        "Calibrating your daily rules",
                        "Setting your start — OVR \(viewModel.diagnosticOVR)",
                        "Projecting your \(viewModel.setup.durationDays)-day climb"],
                onAdvance: viewModel.advance)
        case .projection:
            ProjectionScreen(base: OVREngine.startingOVR(from: viewModel.draft.answers),
                             days: viewModel.setup.durationDays,
                             projectedOVR: viewModel.projectedOVR,
                             projectedRank: viewModel.projectedRank,
                             date: viewModel.projectionDate,
                             onAdvance: viewModel.advance)
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

        // MARK: Act 4 — post-paywall

        case .notifications:
            NotificationsScreen(reminderMinutes: viewModel.reminderMinutes,
                                onAdvance: viewModel.advance)
        case .loaderSetup:
            OnboardingLoaderScreen(
                title: "Setting up your protocol…",
                steps: ["Saving your protocol",
                        "Scheduling your daily reminder",
                        "Preparing your dojo",
                        "Lighting your streak"],
                footer: "Day 1 starts today. Almost there.",
                duration: OnboardingMetrics.setupLoaderDuration,
                // "Saving your protocol" is not a lie: the challenge is born here.
                // Exactly-once is the store's own invariant, so a backgrounded
                // loader replaying its .task cannot mint a second one.
                work: viewModel.commitChallenge,
                onFinished: viewModel.advance)
        case .welcomeDojo:
            WelcomeDojoScreen(rank: viewModel.playerRank,
                              reminderMinutes: viewModel.reminderMinutes,
                              onAdvance: viewModel.advance)
        case .widgetPromo:
            WidgetPromoScreen(onFinish: viewModel.finish)
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
