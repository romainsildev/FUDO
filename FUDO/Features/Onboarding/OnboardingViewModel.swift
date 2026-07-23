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

    /// OB 17's view state, hoisted (batch #12): the paywall's X walks back to
    /// the contract and RECREATES the screen — a signed contract must come back
    /// signed (his stroke intact, the stamp posed, Continue up), not blank.
    /// Session memory, like the one-shot flags.
    var signatureStrokes: [[CGPoint]] = []
    private(set) var contractSealed = false

    /// The 60-seconds beat plays ONCE per funnel run (batch #4): backing out
    /// of the quiz must land on the FINISHED state — lock line + CTA posed —
    /// never replay the launch. Session memory, deliberately not persisted.
    private(set) var sixtySecondsPlayed = false

    /// OB 13's "Locking…" beat, same one-shot pattern: a re-entry on the
    /// projection poses the revealed state cold, never the loader again.
    private(set) var projectionPlayed = false

    /// OB 15's duel track draws ONCE (same one-shot pattern): a back re-entry
    /// poses the finished track cold, never replays the draw-in.
    private(set) var socialProofPlayed = false

    /// OB 12's analysis no longer auto-starts (batch #10, Romain — perceived
    /// consent): the user taps "Analyze my answers". This remembers he did, so a
    /// re-render doesn't drop him back to the waiting state.
    private(set) var analysisStarted = false

    // MARK: - Analytics session state (ANALYTICS-PLAN §1.2)
    /// Screens counted for `onboarding_completed.screens_seen`; start time for its
    /// `duration_seconds`. `didTrackCompleted` makes that event exactly-once.
    private var analyticsScreensSeen = 0
    private var analyticsStartedAt: Date?
    private var didTrackCompleted = false

    init(store: GameStore, flags: OnboardingFlags = OnboardingFlags(),
         onFinished: @escaping () -> Void = {}) {
        self.store = store
        self.flags = flags
        self.onFinished = onFinished
        self.step = flags.resumeStep   // kill-safety: a relaunch re-enters where he stopped
        self.setup = ChallengeSetupViewModel(store: store, recommendedPreset: .monk60)
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
        case .wakeUp: return draft.wakeTime != nil
        case .training: return draft.trainingLoad != nil
        case .focus: return draft.focusSpan != nil
        case .goals: return !draft.goals.isEmpty
        case .struggle: return draft.struggle != nil
        case .attempts: return draft.quitHistory != nil
        case .commitment: return draft.commitment != nil
        // 11a always advances: the chips default to the recommendation, a
        // duration always exists. 11b gates on composing only (BUG B, carnet).
        case .composeRules: return setup.canCompose
        case .contract: return hasSignature
        default: return true
        }
    }

    func advance() {
        advance(force: false)
    }

    /// `force` bypasses the spam guard — for the CHECKPOINT advances only
    /// (signContract, passPaywall): those are commits, not CTA taps, and a
    /// guard armed by the previous screen must never swallow them (it left
    /// `hasCompletedOnboarding` set with the step stuck on the paywall — the
    /// resume write below never ran).
    private func advance(force: Bool) {
        guard force || !isAdvancing, canAdvance, let next = step.next else { return }
        trackAdvancingAway(from: step)
        isAdvancing = true
        Haptics.light()
        direction = .forward
        step = next
        persistPostPaywallResume()
        releaseGuard()
    }

    /// Kill-safety: once the paywall is passed, remember the exact trio step so a
    /// relaunch (e.g. he left to add the widget on OB 21) resumes right here and
    /// not at the top of the trio.
    private func persistPostPaywallResume() {
        guard flags.hasCompletedOnboarding else { return }
        flags.postPaywallStep = step
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

    // MARK: - Analytics (ANALYTICS-PLAN §1.2)

    /// Fired by the flow on every step appearance (`onChange(initial:)`), so it is
    /// the exact onAppear-equivalent for `onboarding_screen_viewed`. `step` = the
    /// OB index; `screen` = its stable name. The projection screen also emits its
    /// own OVR event here.
    func trackScreenAppeared() {
        if analyticsStartedAt == nil { analyticsStartedAt = Date() }
        analyticsScreensSeen += 1
        Analytics.track(AnalyticsEvent.onboardingScreenViewed,
                        ["step": step.rawValue, "screen": step.analyticsScreen])
        if step == .projection {
            Analytics.track(AnalyticsEvent.onboardingProjectionViewed,
                            ["starting_ovr": diagnosticOVR,
                             "projected_ovr": OVREngine.displayedOVR(projectedOVR)])
        }
    }

    /// Committing an answer by advancing = the `question_answered` moment; leaving
    /// the rules screen (11b) = `challenge_composed`. Both fire before the step moves.
    private func trackAdvancingAway(from step: OnboardingStep) {
        if let qa = OnboardingAnalytics.questionAnswer(for: step, draft: draft) {
            Analytics.track(AnalyticsEvent.onboardingQuestionAnswered,
                            ["step": step.rawValue, "question": qa.question, "answer": qa.answer])
        }
        if step == .composeRules {
            Analytics.track(AnalyticsEvent.onboardingChallengeComposed,
                            ["preset": setup.selectedPreset.rawValue,
                             "duration_days": setup.durationDays,
                             "rules_count": setup.enabledRules.count,
                             "rules_edited": setup.rulesEdited])
        }
    }

    /// End of the persuasion funnel (contract signed → paywall). Exactly-once.
    /// Also posts the four person properties — the only $set (plan §4).
    private func trackOnboardingCompleted() {
        guard !didTrackCompleted else { return }
        didTrackCompleted = true
        let seconds = analyticsStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        Analytics.track(AnalyticsEvent.onboardingCompleted,
                        ["duration_seconds": seconds, "screens_seen": analyticsScreensSeen])
        Analytics.set(person: OnboardingAnalytics.personProperties(draft: draft,
                                                                   preset: setup.selectedPreset))
    }

    #if DEBUG
    /// Tests and the debug menu only — production walks the funnel one step at a time.
    func jump(to step: OnboardingStep) {
        self.step = step
    }
    #endif

    /// The flow-level chrome (bar + chevron). The step decides (`showsProgress`)
    /// with ONE dynamic exception: the projection's "Locking…" beat is a loader,
    /// and loaders never carry the bar — it returns with the reveal (batch #5).
    var showsChrome: Bool {
        if step == .projection && !projectionPlayed { return false }
        return step.showsProgress
    }

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

    // MARK: - The 60-seconds beat

    func markSixtySecondsPlayed() { sixtySecondsPlayed = true }

    // MARK: - OB 13 — the locking beat

    func markProjectionPlayed() { projectionPlayed = true }

    // MARK: - OB 15 — the duel track

    func markSocialProofPlayed() { socialProofPlayed = true }

    // MARK: - OB 12 — the analysis loader

    func markAnalysisStarted() { analysisStarted = true }

    // MARK: - OB 11a

    /// Called on entering the duration screen (11a — the compose split's first
    /// half). The recommendation is constant today, so this is a no-op — it
    /// exists so the day the rule changes, ONE place changes.
    func prepareCompose() {
        let recommended = OnboardingCopy.recommendedPreset(for: draft)
        guard recommended != setup.recommendedPreset else { return }
        setup = ChallengeSetupViewModel(store: store, recommendedPreset: recommended)
    }

    // MARK: - OB 11b — personalized rules (batch #12)

    /// Which preset the current rule set was personalized against — changing
    /// the duration reloads preset defaults (chip semantics), so 11b re-derives.
    private var personalizedForPreset: ChallengePreset?

    /// Swaps the preset's default rules for the personalized cut: full catalog
    /// visible, ~4 pre-selected from his answers. Idempotent per preset — his
    /// toggles survive a back-and-forth that doesn't change the duration.
    func preparePersonalizedRules() {
        guard personalizedForPreset != setup.selectedPreset else { return }
        setup.rules = RulePersonalizer.rules(for: draft)
        personalizedForPreset = setup.selectedPreset
    }

    // MARK: - OB 17 — checkpoint 1

    func registerSignature() { hasSignature = true }

    /// "Clear" (tester batch #1): revokes the FACT of the signature — the CTA
    /// goes dead again. The strokes live here too since batch #12 (paywall
    /// round trip), so both die together.
    func clearSignature() {
        hasSignature = false
        signatureStrokes = []
    }

    /// The hold completed and the stamp landed — one-way, survives the paywall's
    /// X. The screen poses the sealed end state cold on re-entry (no replay).
    func markContractSealed() { contractSealed = true }

    /// Checkpoint 1 (kill-safety): the player becomes REAL here — his OVR exists even
    /// if he kills the app at the paywall. The CHALLENGE does not: its day-1 clock
    /// must not tick while he's blocked behind a paywall he hasn't passed.
    func signContract() {
        // The step guard is what makes the forced advance safe: a double tap
        // lands with step already on .paywall and dies here — a forced advance
        // without it would sign twice and SKIP the paywall.
        guard hasSignature, step == .contract else { return }
        let startingOVR = OVREngine.startingOVR(from: draft.answers)
        store.ensurePlayer(startingOVR: startingOVR)
        flags.contract = ContractSnapshot(
            startingOVR: startingOVR,
            projectedOVR: projectedOVR,
            preset: setup.selectedPreset,
            durationDays: setup.durationDays,
            reminderMinutes: setup.reminderMinutes,
            rules: setup.enabledRules.map { .init(title: $0.title, iconName: $0.iconName) })
        trackOnboardingCompleted()
        advance(force: true)
    }

    // MARK: - Paywall — checkpoint 2

    /// The quiz never replays after this. The hold-lock takes over: `isFullyDone`
    /// stays false until the post-paywall trio is done.
    func passPaywall() {
        guard step == .paywall else { return }   // same double-tap seal as the contract
        flags.hasCompletedOnboarding = true
        advance(force: true)
    }

    /// The paywall's discreet X (appears after 3 s): back to the signed contract.
    /// Not `back()` — the paywall carries no chevron (`showsBack` is false), and
    /// there is no free zone to explore: the only exits are purchase or here.
    func closePaywall() {
        guard !isAdvancing, step == .paywall else { return }
        isAdvancing = true
        direction = .backward
        step = .contract
        releaseGuard()
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
                             reminderMinutes: contract.reminderMinutes,
                             origin: .onboarding)
    }

    // MARK: - OB 21 — checkpoint 3

    /// The trio is done: the hold-lock opens and the cover drops onto Home day 1.
    func finish() {
        Haptics.success()
        flags.markFullyCompleted()
        onFinished()
    }
}
