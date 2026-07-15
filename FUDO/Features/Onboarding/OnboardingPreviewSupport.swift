#if DEBUG
import SwiftData
import SwiftUI

/// Canvas support for every onboarding screen. ONE file, ONE container — the two
/// pitfalls from the carnet are both structural here, not stylistic:
///
///  1. **One container for the whole process.** Since Xcode 15 a preview boots the
///     REAL app; `FUDOApp` already goes empty under `XCODE_RUNNING_FOR_PREVIEWS`,
///     but if each screen's preview built its own container they'd stack up and
///     SwiftData would trap on insert (iOS 17 multi-container bug). Every screen
///     previews against THIS store.
///  2. **The factory retains the container.** `container.mainContext` does not
///     hold its ModelContainer: a container built inside a closure deallocates,
///     SwiftData resets the context, and the canvas dies with "Fatal Error in
///     BackingData.swift". Hence `static let`, never a computed property.
///
/// The store is deliberately EMPTY (no player, no challenge): that is the only
/// state the funnel ever runs against in real life.
@MainActor
enum OnboardingPreviewFactory {
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

    static let store = GameStore(modelContext: container.mainContext)

    /// A throwaway defaults suite per preview name, so a canvas run never writes
    /// the real onboarding flags (nor marks the review prompt as fired).
    static func flags(_ name: String = "preview.onboarding") -> OnboardingFlags {
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return OnboardingFlags(defaults: defaults)
    }

    static func viewModel(step: OnboardingStep = .splash,
                          draft: OnboardingDraft = .previewAnswered) -> OnboardingViewModel {
        let viewModel = OnboardingViewModel(store: store, flags: flags(UUID().uuidString))
        viewModel.draft = draft
        viewModel.jump(to: step)
        return viewModel
    }
}

// MARK: - Draft fixtures

extension OnboardingDraft {
    /// The canonical answered funnel: 4-6 h of scrolling at 18-24, training is the
    /// pain. Base 40 + 3 + 0 + 1 = 44 before the commitment bonus.
    static var previewAnswered: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .trainingConsistently
        draft.scrollTime = .fourToSixHours
        draft.age = .young1824
        draft.procrastination = .everyWeek
        draft.goals = [.leanerBody, .killScrolling, .harderMindset]
        draft.struggle = .threeDaysMax
        return draft
    }

    /// The heaviest case: a teenager at 6 h+, doomscrolling. Worst shock number.
    static var previewHeavy: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .doomscrolling
        draft.scrollTime = .sixHoursPlus
        draft.age = .teen1317
        draft.procrastination = .everyWeek
        draft.goals = [.killScrolling]
        draft.struggle = .cantEvenStart
        return draft
    }

    /// The disciplined case: under 2 h — the shock falls under a year and flips
    /// to days. Reading is the pain.
    static var previewLight: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .reading
        draft.scrollTime = .underTwoHours
        draft.age = .young1824
        draft.procrastination = .stoppedLyingToMyself
        draft.goals = [.readDaily, .harderMindset]
        draft.struggle = .startStrongThenQuit
        return draft
    }
}

// MARK: - Chrome

/// Puts a screen in the flow's chrome so the canvas reads like the app: the ink
/// background, and for the welcome act the video stage under its scrim.
///
/// Without this a hook floats on grey and there is nothing to judge — the whole
/// point of Act 0 is the copy holding over moving footage. (In the canvas the
/// video usually won't decode, so what renders is the still fallback — which is
/// exactly the path worth checking too.)
struct OnboardingPreviewChrome<Content: View>: View {
    var clip: WelcomeClip?
    var isSplash = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            if let clip {
                WelcomeStageView(clip: clip).ignoresSafeArea()
                WelcomeScrim(isSplash: isSplash).ignoresSafeArea()
            }
            content()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
