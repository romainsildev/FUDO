import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Settings", subtitle: "Functional, not rich.") {
            #if DEBUG
            // Scaffolding that proves the tab bar hides on push — never in a
            // submitted build (no dead buttons, known-pitfalls list).
            NavigationLink(value: PushDemoDestination(title: "Settings subscreen")) {
                Text("Push demo →")
                    .fudoFont(.body())
                    .foregroundStyle(FudoColor.accent)
            }
            DebugMenuSection()
                .padding(.top, FudoSpacing.sectionGap)
            #endif
        }
        #if DEBUG
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
        #endif
    }
}
