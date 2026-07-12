import SwiftUI

struct HomePlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Today", subtitle: "Home — daily checklist lives here.") {
            NavigationLink(value: PushDemoDestination(title: "Today detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
