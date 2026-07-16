import CoreGraphics
import Foundation

/// Every onboarding-only constant — no magic numbers in the screens (CLAUDE.md).
/// Motion stays inside the 0.4-0.6 s house curve (AppAnimation); the values here
/// are BEATS (how long a moment lasts), not curves.
enum OnboardingMetrics {
    /// Cross-fade between two welcome clips (01a → 01b → 01c) and on the loop seam.
    static let videoCrossfade: TimeInterval = 0.5
    /// Welcome ambience playback rate (device pass 2026-07-16): half speed —
    /// calmer scene, longer runway before the loop seam. Tune within 0.4–0.6.
    static let videoRate: Float = 0.5
    /// Splash hint "Tap anywhere" — slow breath, never a blink.
    static let hintPulse: TimeInterval = 1.8
    /// Ensō scale-in on the splash.
    static let ensoScaleFrom: CGFloat = 0.96

    /// The FUDO wordmark, shared across the whole welcome act (device batch
    /// 2026-07-16): full size on the ensō, docked at the top of the hooks.
    /// ONE view slides between the two states (WelcomeWordmark) — the screens
    /// only reserve its slot, nobody else draws "FUDO".
    enum Wordmark {
        static let splashSize: CGFloat = 34
        static let splashKerning: CGFloat = 8
        static let dockedSize: CGFloat = 20
        static let dockedKerning: CGFloat = 6
        static let dockedTopPadding: CGFloat = 8
    }

    /// OB 12 "Building your protocol…" — 4 narrative steps.
    /// OB 12's ring fill — long enough for five orbiting stats to live and die
    /// (narrative loader, 2026-07-16). The exit is the user's tap, not a timer.
    static let buildLoaderDuration: TimeInterval = 8.0
    /// OB 19 "Setting up your protocol…" — the brief's ~7 s beat.
    static let setupLoaderDuration: TimeInterval = 7.0

    /// OB 06 count-up of the shock number — sober, no bounce.
    static let countUpDuration: TimeInterval = 1.2
    /// OB 10 / OB 13 reveal beat before the number lands.
    static let revealDelay: TimeInterval = 0.35

    /// OB 15 — let the screen settle before the system sheet takes over.
    static let reviewPromptDelay: TimeInterval = 0.8

    /// OB 17 "HOLD TO SIGN" — heavier than a checklist hold: this one binds.
    static let signHoldDuration: TimeInterval = 2.5
    /// OB 14's HOLD ring: a 148 pt circle needs a thicker stroke than a card's 3 pt.
    static let firstCheckRingDiameter: CGFloat = 148
    static let firstCheckRingWidth: CGFloat = 7
    /// How long the day-0 flame lingers before OB 14 auto-advances.
    static let firstCheckSettle: TimeInterval = 1.4

    /// Ignore a second CTA tap fired inside one transition (RiteOff ctaSpamGuard).
    static let ctaGuard: TimeInterval = 0.5

    /// Bebas hook sizes (brief, verbatim).
    enum Hook {
        static let transformationLead: CGFloat = 34
        static let transformationClimax: CGFloat = 62
        static let painLead: CGFloat = 42
        static let painClimax: CGFloat = 56
        static let mechanismLead: CGFloat = 46
        static let mechanismClimax: CGFloat = 72
        /// A 62 pt Bebas line at AX sizes would overflow the phone: let it shrink
        /// rather than truncate. The hook IS the screen — it never wraps to 3 lines.
        static let minimumScale: CGFloat = 0.75
    }
}
