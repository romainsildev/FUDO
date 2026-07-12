import SwiftUI
import Observation

/// Shared override so a screen can force-hide the floating pill regardless of
/// nav-path depth (belt-and-suspenders; primary hide is path-driven in MainTabView).
@Observable final class TabBarVisibility {
    var isHidden = false
}

private struct HidesTabBarModifier: ViewModifier {
    @Environment(TabBarVisibility.self) private var visibility
    func body(content: Content) -> some View {
        content
            .onAppear { visibility.isHidden = true }
            .onDisappear { visibility.isHidden = false }
    }
}

extension View {
    /// Force-hide the floating pill while this view is on screen.
    func fudoHidesTabBar() -> some View { modifier(HidesTabBarModifier()) }
}
