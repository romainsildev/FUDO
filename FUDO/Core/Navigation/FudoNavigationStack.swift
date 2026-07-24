import SwiftUI

/// Reusable PUSH container: native back, tab bar hidden (MainTabView hides the pill
/// when this stack's path is non-empty). Each root declares its own `.navigationDestination`.
struct FudoNavigationStack<Root: View>: View {
    @Binding var path: NavigationPath
    @ViewBuilder let root: () -> Root

    var body: some View {
        NavigationStack(path: $path) { root() }
    }
}
