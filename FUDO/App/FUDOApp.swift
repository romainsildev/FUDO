import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    init() {
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
