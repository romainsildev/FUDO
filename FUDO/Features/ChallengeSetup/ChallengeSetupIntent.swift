import Foundation

/// A pre-filled entry into the standalone setup screen. Produced by the
/// challenge-complete cover's beat-3 CTAs (Next challenge / Restart harder) and
/// consumed by RootView to present `ChallengeSetupStandaloneView` seeded with the
/// right preset and rules. `Identifiable` so it drives a `fullScreenCover(item:)`.
///
/// - `recommendedPreset`: which chip wears the "RECOMMENDED FOR YOU" label.
/// - `initialPreset`: the chip selected on entry (Next = the superior preset;
///   Restart = the same preset just finished).
/// - `initialRules`: seed rules that survive until the user changes a chip
///   (Restart injects the reused set + escalation); nil falls back to the
///   preset's default protocol (Next).
struct ChallengeSetupIntent: Identifiable {
    let recommendedPreset: ChallengePreset
    let initialPreset: ChallengePreset
    let initialRules: [EditableRule]?
    let id = UUID()
}
