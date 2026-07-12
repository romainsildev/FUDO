import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Settings", subtitle: "Functional, not rich.") {
            NavigationLink(value: PushDemoDestination(title: "Settings subscreen")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
