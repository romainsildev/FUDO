#if DEBUG
import SwiftUI
import SwiftData

/// One shared, in-memory, seeded store for the app-tab canvas previews — Stats,
/// Progression, and Habit detail. A SINGLE factory for the whole set on purpose: a
/// per-file factory would mint a second `ModelContainer` in the same preview process and
/// trip the iOS 17 multi-container crash (carnet 2026-07-15 / S5 — the Onboarding module
/// learned the same lesson with `OnboardingPreviewFactory`).
///
/// The seed (`DebugSeed`) lands the canvas on the mock's exact state: OVR 61 Ascetic,
/// Day 12/30, streak 4 — so the previews read like the Figma frames without a build.
///
/// The container is retained in a `static let`: `mainContext` does NOT keep its container
/// alive, and once it deallocs SwiftData resets the context and destroys every fetched
/// model ("Fatal Error in BackingData.swift", canvas crash 2026-07-15). Same reason
/// `FUDOApp` stores its container.
@MainActor
enum AppPreviewFactory {
    static let container: ModelContainer? = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let built = try ModelContainer(for: FudoSchema.schema, configurations: config)
            DebugSeed.seed(context: built.mainContext)
            return built
        } catch {
            return nil
        }
    }()

    // Built AFTER the seed — the seed replays through its own GameStore, so a fresh
    // store fetches the final player/challenge/day-logs.
    static let store: GameStore? = container.map { GameStore(modelContext: $0.mainContext) }

    /// First active rule of the seeded challenge — the subject of the Habit-detail preview.
    static var sampleRuleID: UUID? {
        store?.activeChallenge?.activeRules.first?.id
    }
}
#endif
