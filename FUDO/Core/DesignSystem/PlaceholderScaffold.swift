import SwiftUI

/// Dark, token-styled placeholder. Foundations only — replaced by real screens later.
struct PlaceholderScaffold<Extra: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let extra: () -> Extra

    init(title: String, subtitle: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.extra = extra
    }

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            VStack(spacing: FudoSpacing.cardPadding) {
                Text(title)
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                Text(subtitle)
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.textSecondary)
                    .multilineTextAlignment(.center)
                extra()
            }
            .padding(FudoSpacing.screenMargin)
        }
    }
}

/// Sub-screen pushed by the tab placeholders to prove the tab bar hides on push.
struct PushDemoScreen: View {
    let title: String
    var body: some View {
        PlaceholderScaffold(title: title, subtitle: "Pushed — tab bar hidden, native back restores it.")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .fudoHidesTabBar()
    }
}
