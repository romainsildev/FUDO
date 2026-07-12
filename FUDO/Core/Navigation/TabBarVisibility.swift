import SwiftUI

/// Hides the NATIVE tab bar while this view is on screen — apply to pushed
/// screens (habit detail, Settings subscreens) per nav conventions (prd/12 §1).
/// On iOS 26 the system animates the Liquid Glass bar away natively.
extension View {
    func fudoHidesTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
