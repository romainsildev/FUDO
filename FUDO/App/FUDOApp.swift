import SwiftData
import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    private let container: ModelContainer?
    @State private var gameStore: GameStore?

    init() {
        // Unit tests AND Xcode previews run HOSTED inside this app: if the app also
        // built its real container (+ seed, + RootView rollovers) the process would
        // juggle several live SwiftData containers → EXC_BREAKPOINT on insert (iOS 17
        // multi-container bug; "Fatal Error in BackingData.swift" in the canvas).
        // Under either session the app stays an empty shell; tests own their single
        // in-memory container (SwiftDataTestSupport), previews own theirs
        // (per-preview factory, e.g. HomePreviewFactory).
        let env = ProcessInfo.processInfo.environment
        if env["XCTestSessionIdentifier"] != nil || env["XCTestConfigurationFilePath"] != nil
            || env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            container = nil
            _gameStore = State(initialValue: nil)
            return
        }
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
        do {
            let built = try ModelContainer(for: FudoSchema.schema)
            #if DEBUG
            DebugSeed.seedIfNeeded(context: built.mainContext)
            #endif
            container = built
            _gameStore = State(initialValue: GameStore(modelContext: built.mainContext))
        } catch {
            // 100 % local app, no fallback store: a boot-time container failure is unrecoverable.
            fatalError("ModelContainer creation failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container, let gameStore {
                RootView()
                    .environment(gameStore)
                    .modelContainer(container)
            } else {
                Color.clear   // test-host shell — never visible outside unit-test sessions
            }
        }
    }
}
