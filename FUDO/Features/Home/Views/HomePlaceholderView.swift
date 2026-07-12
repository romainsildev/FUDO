import SwiftUI

/// Session-2 shim: MainTabView (out of this session's write scope) still instantiates
/// `HomePlaceholderView`. The real screen is `HomeView`; the next shell touch renames
/// the call site and deletes this file.
struct HomePlaceholderView: View {
    @Environment(GameStore.self) private var gameStore

    var body: some View {
        HomeView(store: gameStore)
    }
}
