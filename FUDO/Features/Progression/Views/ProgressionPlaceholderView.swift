import SwiftUI

struct ProgressionPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Progress", subtitle: "The challenge and the rank.") {
            NavigationLink(value: PushDemoDestination(title: "Progress detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
