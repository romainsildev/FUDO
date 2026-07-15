import Foundation

/// The composed protocol, frozen at the signature (kill-safety checkpoint 1).
/// Disposable: it exists only between the signature and the challenge's creation
/// at the OB 19 loader. Codable so a kill mid-paywall loses nothing.
struct ContractSnapshot: Codable, Equatable {
    struct Rule: Codable, Equatable {
        var title: String
        var iconName: String
    }

    var startingOVR: Double
    var projectedOVR: Double
    var preset: ChallengePreset
    var durationDays: Int
    var reminderMinutes: Int
    var rules: [Rule]
}

/// Onboarding persistence — flags + the disposable contract draft. NEVER game data
/// (DATA-MODEL: gameplay lives in SwiftData, this lives in UserDefaults).
///
/// `defaults` is injected so tests own a throwaway suite, and so the App Group
/// swap (when the widget target lands) is a ONE-line change here.
final class OnboardingFlags {
    private enum Key {
        static let completed = "onboarding.hasCompleted"
        static let postPaywall = "onboarding.hasFinishedPostPaywall"
        static let contract = "onboarding.contract"
        /// Deliberately OUTSIDE reset(): replaying the funnel in DEBUG must never
        /// ask the user for a review twice.
        static let reviewPrompted = "onboarding.reviewPrompted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Flipped at the paywall (checkpoint 2): the quiz never replays after this.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    /// Flipped at the end of OB 21 (checkpoint 3). The HOLD-LOCK: until it is true,
    /// routing keeps the onboarding cover up even though onboarding "completed".
    var hasFinishedPostPaywall: Bool {
        get { defaults.bool(forKey: Key.postPaywall) }
        set { defaults.set(newValue, forKey: Key.postPaywall) }
    }

    /// One review ask per install — iOS rate-limits its own sheet, this keeps US honest.
    var reviewPrompted: Bool {
        get { defaults.bool(forKey: Key.reviewPrompted) }
        set { defaults.set(newValue, forKey: Key.reviewPrompted) }
    }

    var contract: ContractSnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.contract) else { return nil }
            return try? JSONDecoder().decode(ContractSnapshot.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Key.contract)
                return
            }
            defaults.set(data, forKey: Key.contract)
        }
    }

    /// The ONE gate RootView reads. Both checkpoints must be past.
    var isFullyDone: Bool { hasCompletedOnboarding && hasFinishedPostPaywall }

    /// Where a relaunch re-enters the funnel.
    var resumeStep: OnboardingStep {
        if hasCompletedOnboarding { return .notifications }   // paywall passed → the trio
        if contract != nil { return .paywall }               // signed → straight to the paywall
        return .splash                                        // nothing committed → replay
    }

    /// Checkpoint 3: the trio is done, the challenge exists, the draft is dead weight.
    func markFullyCompleted() {
        hasCompletedOnboarding = true
        hasFinishedPostPaywall = true
        contract = nil
    }

    /// Replays the whole funnel (DEBUG menu). `reviewPrompted` survives on purpose.
    func reset() {
        defaults.removeObject(forKey: Key.completed)
        defaults.removeObject(forKey: Key.postPaywall)
        defaults.removeObject(forKey: Key.contract)
    }
}
