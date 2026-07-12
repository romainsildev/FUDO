import SwiftUI

struct StatsPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Stats", subtitle: "The habits.") {
            NavigationLink(value: PushDemoDestination(title: "Habit detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
