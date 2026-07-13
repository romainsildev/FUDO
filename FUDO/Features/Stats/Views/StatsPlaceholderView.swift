import SwiftUI

/// Session-S4bis shim: MainTabView (out of this session's write scope) still instantiates
/// `StatsPlaceholderView`. The real screen is `StatsView`; the next shell touch renames
/// the call site and deletes this file. Mirrors `HomePlaceholderView` / `ProgressionPlaceholderView`.
struct StatsPlaceholderView: View {
    @Environment(GameStore.self) private var gameStore

    var body: some View {
        StatsView(store: gameStore)
    }
}
