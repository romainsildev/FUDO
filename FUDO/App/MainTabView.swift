import SwiftUI

/// 4-tab shell on the NATIVE TabView (Romain, 2026-07-12 — RiteOff pattern).
/// On iOS 26 devices the system renders the floating Liquid Glass bar for
/// free; earlier iOS gets the standard bottom bar. Per-tab NavigationPath
/// preserves state per tab. Bar selection tint stays neutral (textPrimary,
/// RiteOff pattern); tab CONTENT re-tints to vermillon so CTAs keep the accent.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var paths: [AppTab: NavigationPath] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) }
    )

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            tab(.today) { HomePlaceholderView() }
            tab(.progress) { ProgressionPlaceholderView() }
            tab(.stats) { StatsPlaceholderView() }
            tab(.settings) { SettingsView() }
        }
        .tint(FudoColor.textPrimary)
        .onChange(of: appState.selectedTab) { _, _ in Haptics.light() }
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: @escaping () -> Root) -> some View {
        FudoNavigationStack(path: pathBinding(tab)) { root().tint(FudoColor.accent) }
            .tabItem { Label(tab.title, systemImage: tab.icon) }
            .tag(tab)
    }

    private func pathBinding(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { paths[tab] ?? NavigationPath() },
            set: { paths[tab] = $0 }
        )
    }
}
