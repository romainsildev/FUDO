import SwiftUI

/// 4-tab shell. Per-tab NavigationPath preserves state per tab. The floating pill is an
/// overlay above the stock (hidden) tab bar; it hides whenever the selected tab has pushed.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var visibility = TabBarVisibility()
    @State private var paths: [AppTab: NavigationPath] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) }
    )

    private var pillHidden: Bool {
        let pushed = !(paths[appState.selectedTab]?.isEmpty ?? true)
        return pushed || visibility.isHidden
    }

    var body: some View {
        @Bindable var appState = appState
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                tab(.today) { HomePlaceholderView() }
                tab(.progress) { ProgressionPlaceholderView() }
                tab(.stats) { StatsPlaceholderView() }
                tab(.settings) { SettingsPlaceholderView() }
            }

            if !pillHidden {
                FudoTabBar(selected: $appState.selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(visibility)
        .animation(AppAnimation.standard, value: pillHidden)
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: @escaping () -> Root) -> some View {
        FudoNavigationStack(path: pathBinding(tab)) { root() }
            .toolbar(.hidden, for: .tabBar)
            .tag(tab)
    }

    private func pathBinding(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { paths[tab] ?? NavigationPath() },
            set: { paths[tab] = $0 }
        )
    }
}
