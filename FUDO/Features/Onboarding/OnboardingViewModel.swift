import Observation
import SwiftUI

/// The ONE brain of the funnel: which screen, which direction, what he answered,
/// and the two kill-safety checkpoints. Every number it exposes comes from
/// OVREngine — the funnel computes nothing of its own (CLAUDE.md).
@MainActor
@Observable
final class OnboardingViewModel {

    enum Direction { case forward, backward }

    private let store: GameStore
    private let flags: OnboardingFlags
    private let onFinished: () -> Void

    private(set) var step: OnboardingStep
    private(set) var direction: Direction = .forward
    var draft = OnboardingDraft()

    /// The 4th skin of the ONE setup view model (full flow, onboarding inline,
    /// standalone cover, and this). Preset/rule logic never gets re-implemented here.
    private(set) var setup: ChallengeSetupViewModel

    /// A second tap fired inside the transition is the user's finger, not his
    /// intent: it would skip a whole screen. Guard = a flag the transition owns.
    private(set) var isAdvancing = false

    /// OB 17 — the CTA stays dead until his finger has left a stroke.
    private(set) var hasSignature = false

    init(store: GameStore, flags: OnboardingFlags = OnboardingFlags(),
         onFinished: @escaping () -> Void = {}) {
        self.store = store
        self.flags = flags
        self.onFinished = onFinished
        self.step = flags.resumeStep   // kill-safety: a relaunch re-enters where he stopped
        self.setup = ChallengeSetupViewModel(store: store, recommendedPreset: .monk30)
    }

    // MARK: - Navigation

    /// Per-screen gate: the CTA is dead until THIS screen's answer exists.
    /// Never a live button that does nothing (known-pitfalls list).
    var canAdvance: Bool {
        switch step {
        case .painPoint: return draft.pain != nil
        case .scrollHours: return draft.scrollTime != nil
        case .age: return draft.age != nil
        case .procrastination: return draft.procrastination != nil
        case .goals: return !draft.goals.isEmpty
        case .struggle: return draft.struggle != nil
        case .commitment: return draft.commitment != nil
        case .compose: return setup.canCommit
        case .contract: return hasSignature
        default: return true
        }
    }

    func advance() {
        guard !isAdvancing, canAdvance, let next = step.next else { return }
        isAdvancing = true
        Haptics.light()
        direction = .forward
        step = next
        releaseGuard()
    }

    func back() {
        guard !isAdvancing, step.showsBack, let previous = step.previous else { return }
        isAdvancing = true
        Haptics.light()
        direction = .backward
        step = previous
        releaseGuard()
    }

    private func releaseGuard() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(OnboardingMetrics.ctaGuard))
            isAdvancing = false
        }
    }

    #if DEBUG
    /// Tests and the debug menu only — production walks the funnel one step at a time.
    func jump(to step: OnboardingStep) {
        self.step = step
    }
    #endif

    /// Horizontal slide + fade: the funnel reads as forward motion. The welcome act
    /// overrides it with a pure crossfade (the video must never slide).
    var transition: AnyTransition {
        if step.isWelcome { return .opacity }
        let insertion: Edge = direction == .forward ? .trailing : .leading
        let removal: Edge = direction == .forward ? .leading : .trailing
        return .asymmetric(insertion: .move(edge: insertion).combined(with: .opacity),
                           removal: .move(edge: removal).combined(with: .opacity))
    }

    var welcomeClip: WelcomeClip {
        switch step {
        case .pain: return .phone
        case .mechanism: return .doors
        default: return .dojo   // splash + transformation share the dojo: the scene never restarts
        }
    }

    // MARK: - Derivations (every one of them through OVREngine)

    var shock: ShockMath.Result? {
        guard let age = draft.age, let scroll = draft.scrollTime else { return nil }
        return ShockMath.result(age: age, scroll: scroll)
    }

    /// D1: the FLOOR. `draft.answers` defaults commitment to `.somewhat` (0 pt) until
    /// OB 16 answers it, so this number can only go UP later — never down.
    var diagnosticOVR: Int { OVREngine.displayedOVR(OVREngine.startingOVR(from: draft.answers)) }

    var diagnosticRank: Rank { OVREngine.rank(forOVR: OVREngine.startingOVR(from: draft.answers)) }

    var projectedOVR: Double {
        OVREngine.project(from: OVREngine.startingOVR(from: draft.answers), days: setup.durationDays)
    }

    var projectedRank: Rank { OVREngine.rank(forOVR: projectedOVR) }

    /// Day 1 is today → the last day is today + duration − 1. Read from the setup
    /// VM, never re-derived: two definitions of "the end date" is one too many.
    var projectionDate: Date { setup.endDate }

    var reminderMinutes: Int { setup.reminderMinutes }

    /// The rank OB 20 greets him with — read from the REAL player (he exists by
    /// then: the signature created him). Falls back to the diagnostic rank so the
    /// dojo can never greet a man who isn't there.
    var playerRank: Rank { store.player?.rank ?? diagnosticRank }

    // MARK: - OB 11

    /// Called on entering the compose screen. D3 makes the answer constant today,
    /// so this is a no-op — it exists so the day the rule changes, ONE place changes.
    func prepareCompose() {
        let recommended = OnboardingCopy.recommendedPreset(for: draft)
        guard recommended != setup.recommendedPreset else { return }
        setup = ChallengeSetupViewModel(store: store, recommendedPreset: recommended)
    }

    // MARK: - OB 17 — checkpoint 1

    func registerSignature() { hasSignature = true }

    /// Checkpoint 1 (kill-safety): the player becomes REAL here — his OVR exists even
    /// if he kills the app at the paywall. The CHALLENGE does not: its day-1 clock
    /// must not tick while he's blocked behind a paywall he hasn't passed.
    func signContract() {
        guard hasSignature else { return }
        let startingOVR = OVREngine.startingOVR(from: draft.answers)
        store.ensurePlayer(startingOVR: startingOVR)
        flags.contract = ContractSnapshot(
            startingOVR: startingOVR,
            projectedOVR: projectedOVR,
            preset: setup.selectedPreset,
            durationDays: setup.durationDays,
            reminderMinutes: setup.reminderMinutes,
            rules: setup.enabledRules.map { .init(title: $0.title, iconName: $0.iconName) })
        advance()
    }

    // MARK: - Paywall — checkpoint 2

    /// The quiz never replays after this. The hold-lock takes over: `isFullyDone`
    /// stays false until the post-paywall trio is done.
    func passPaywall() {
        flags.hasCompletedOnboarding = true
        advance()
    }

    // MARK: - OB 19 — the real work behind "Saving your protocol"

    /// The challenge is created HERE, after the paywall, so day 1 starts when he
    /// actually reaches the dojo. Exactly-once by construction: the snapshot guard
    /// plus GameStore's own "one .active challenge" invariant — a backgrounded
    /// loader that replays its .task cannot mint a second challenge.
    func commitChallenge() {
        guard let contract = flags.contract, store.activeChallenge == nil else { return }
        store.ensurePlayer(startingOVR: contract.startingOVR)
        store.startChallenge(preset: contract.preset,
                             durationDays: contract.durationDays,
                             rules: contract.rules.map { RuleDraft(title: $0.title, iconName: $0.iconName) },
                             reminderMinutes: contract.reminderMinutes)
    }

    // MARK: - OB 21 — checkpoint 3

    /// The trio is done: the hold-lock opens and the cover drops onto Home day 1.
    func finish() {
        Haptics.success()
        flags.markFullyCompleted()
        onFinished()
    }
}
