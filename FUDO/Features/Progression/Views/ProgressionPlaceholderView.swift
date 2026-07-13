import SwiftUI

/// Session-4 shim: MainTabView (out of this session's write scope) still instantiates
/// `ProgressionPlaceholderView`. The real screen is `ProgressionView`; the next shell touch
/// renames the call site and deletes this file. Mirrors `HomePlaceholderView`.
struct ProgressionPlaceholderView: View {
    @Environment(GameStore.self) private var gameStore

    var body: some View {
        ProgressionView(store: gameStore)
    }
}
