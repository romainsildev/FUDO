import RevenueCat
import SwiftData
import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    // The notification delegate lives in UIKit (SwiftUI can't own it); it forwards
    // taps into NotificationRouter for RootView to present.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer?
    @State private var gameStore: GameStore?
    @State private var entitlementStore: EntitlementStore?

    init() {
        // Unit tests AND Xcode previews run HOSTED inside this app: if the app also
        // built its real container (+ seed, + RootView rollovers) the process would
        // juggle several live SwiftData containers → EXC_BREAKPOINT on insert (iOS 17
        // multi-container bug; "Fatal Error in BackingData.swift" in the canvas).
        // Under either session the app stays an empty shell; tests own their single
        // in-memory container (SwiftDataTestSupport), previews own theirs
        // (per-preview factory, e.g. HomePreviewFactory). The same guard keeps
        // Purchases.configure out of tests/canvas — EntitlementStore no-ops unconfigured.
        let env = ProcessInfo.processInfo.environment
        if env["XCTestSessionIdentifier"] != nil || env["XCTestConfigurationFilePath"] != nil
            || env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            container = nil
            _gameStore = State(initialValue: nil)
            _entitlementStore = State(initialValue: nil)
            return
        }
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
        // RevenueCat FIRST (before any routing decision): configuring at launch
        // revives the SDK's local CustomerInfo cache, so a paying user resolves
        // as pro within the first frames — offline included, never a paywall flash.
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        // Analytics next — PostHog in Release, a no-op in DEBUG (zero capture, so
        // dev/seed data never pollutes the funnels). All events go through the
        // `Analytics` facade; no other file imports PostHog.
        Analytics.configure()
        let entitlements = EntitlementStore()
        entitlements.start()
        _entitlementStore = State(initialValue: entitlements)
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
            if let container, let gameStore, let entitlementStore {
                RootView()
                    .environment(gameStore)
                    .environment(entitlementStore)
                    .environment(NotificationRouter.shared)
                    .modelContainer(container)
            } else {
                Color.clear   // test-host shell — never visible outside unit-test sessions
            }
        }
    }
}
