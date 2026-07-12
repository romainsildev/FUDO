import SwiftData
import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    private let container: ModelContainer
    @State private var gameStore: GameStore

    init() {
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
        do {
            container = try ModelContainer(
                for: Challenge.self, TaskRule.self, DayLog.self, PlayerState.self)
        } catch {
            // 100 % local app, no fallback store: a boot-time container failure is unrecoverable.
            fatalError("ModelContainer creation failed: \(error)")
        }
        #if DEBUG
        DebugSeed.seedIfNeeded(context: container.mainContext)
        #endif
        _gameStore = State(initialValue: GameStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameStore)
        }
        .modelContainer(container)
    }
}
